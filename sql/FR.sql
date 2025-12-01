-- this will register a user
CREATE OR REPLACE FUNCTION member_register(p_email VARCHAR, p_password VARCHAR, p_full_name VARCHAR, p_dob DATE, p_gender gender_type, p_phone VARCHAR, p_emergency_contact VARCHAR) 
RETURNS INT AS $$
DECLARE
    new_member_id INT;
BEGIN
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        RETURN 0;
    END IF;
    INSERT INTO users(email, password_hash, full_name, date_of_birth, gender, phone, role)
    VALUES (p_email, p_password, p_full_name, p_dob, p_gender, p_phone, 'member')
    RETURNING user_id INTO new_member_id;

    INSERT INTO members(member_id, emergency_contact)
    VALUES (new_member_id, p_emergency_contact);

    RETURN new_member_id;
END;
$$ LANGUAGE plpgsql;

-- this will manage the profile
CREATE OR REPLACE FUNCTION member_update_profile(p_member_id INT, p_full_name VARCHAR, p_phone VARCHAR, p_goal_type VARCHAR, p_target_value NUMERIC) 
RETURNS TEXT AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM members WHERE member_id = p_member_id) THEN
        RETURN 'Error: member id ' || p_member_id || ' does not exist';
    END IF;
    UPDATE users 
    SET full_name = p_full_name, phone = p_phone
    WHERE user_id = p_member_id;
    IF p_goal_type IS NOT NULL THEN
        INSERT INTO fitness_goals(member_id, goal_type, target_value, start_date)
        VALUES (p_member_id, p_goal_type, p_target_value, current_date)
        ON CONFLICT (member_id, goal_type)
        DO UPDATE 
        SET target_value = EXCLUDED.target_value,
            start_date = EXCLUDED.start_date;
    END IF;
    RETURN 'updated successfully';
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION member_add_health_metric(p_member_id INT, p_weight NUMERIC, p_heart_rate INT)
RETURNS TEXT AS $$
BEGIN
    INSERT INTO health_metrics(member_id, weight, heart_rate, recorded_at)
    VALUES (p_member_id, p_weight, p_heart_rate, now());
    RETURN 'health metric added successfully';
END;
$$ LANGUAGE plpgsql;
-- private trainer session scheduling
CREATE OR REPLACE FUNCTION member_schedule_pt(p_member_id INT, p_trainer_id INT, p_room_id INT, p_start timestamptz, p_end timestamptz)
RETURNS TEXT AS $$
DECLARE
    conflict_count INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM members WHERE member_id = p_member_id) THEN
        RETURN 'member id ' || p_member_id || ' doesnt exist';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM trainers WHERE trainer_id = p_trainer_id) THEN
        RETURN 'trainer id ' || p_trainer_id || ' doesnt exist';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM rooms WHERE room_id = p_room_id) THEN
        RETURN 'room id ' || p_room_id || ' doesnt exist';
    END IF;
    IF p_start >= p_end THEN
        RETURN 'invalid time range';
    END IF;
    SELECT COUNT(*) INTO conflict_count
    FROM pt_sessions
    WHERE trainer_id = p_trainer_id
      AND tstzrange(start_time, end_time, '[)') && tstzrange(p_start, p_end, '[)');
    IF conflict_count > 0 THEN
        RETURN 'the trainer is not available';
    END IF;
    SELECT COUNT(*) INTO conflict_count
    FROM pt_sessions
    WHERE room_id = p_room_id
      AND tstzrange(start_time, end_time, '[)') && tstzrange(p_start, p_end, '[)');
    IF conflict_count > 0 THEN
        RETURN 'the room is not available';
    END IF;
    INSERT INTO pt_sessions(member_id, trainer_id, start_time, end_time, room_id)
    VALUES (p_member_id, p_trainer_id, p_start, p_end, p_room_id);
    RETURN 'private trainer session scheduled successfully';
END;
$$ LANGUAGE plpgsql;

-- group class registration
CREATE OR REPLACE FUNCTION member_register_class(p_member_id INT, p_session_id INT)
RETURNS TEXT AS $$
DECLARE
    class_capacity INT;
    registered_count INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM members WHERE member_id = p_member_id) THEN
        RETURN 'member id ' || p_member_id || ' doesnt exist';
    END IF;
    SELECT capacity INTO class_capacity FROM class_sessions WHERE session_id = p_session_id;
    IF class_capacity IS NULL THEN
        RETURN 'class session not found';
    END IF;
    SELECT COUNT(*) INTO registered_count
    FROM class_registrations
    WHERE session_id = p_session_id;
    IF registered_count >= class_capacity THEN
        RETURN 'the class is full';
    END IF;
    INSERT INTO class_registrations(session_id, member_id)
    VALUES (p_session_id, p_member_id)
    ON CONFLICT DO NOTHING;
    RETURN 'member registered for class successfully';
END;
$$ LANGUAGE plpgsql;
-- this will set availability 
CREATE OR REPLACE FUNCTION trainer_set_availability(p_trainer_id INT, p_start timestamptz, p_end timestamptz) 
RETURNS TEXT AS $$
DECLARE
    conflict_count INT;
BEGIN
    IF p_start >= p_end THEN
        RETURN 'invalid availability time range';
    END IF;

    SELECT COUNT(*) INTO conflict_count
    FROM trainer_availability
    WHERE trainer_id = p_trainer_id
      AND tstzrange(available_start, available_end, '[)') && tstzrange(p_start, p_end, '[)');
    IF conflict_count > 0 THEN
        RETURN 'sorry, but the availability conflicts with a existing schedule';
    END IF;

    INSERT INTO trainer_availability(trainer_id, available_start, available_end)
    VALUES (p_trainer_id, p_start, p_end);
    RETURN 'availability have been added';
END;
$$ LANGUAGE plpgsql;

-- this will schedule a view
CREATE OR REPLACE FUNCTION trainer_schedule_view(p_trainer_id INT)
RETURNS TABLE (session_type TEXT, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, member_count INT, room_id INT)
LANGUAGE plpgsql AS
$$
BEGIN
    RETURN QUERY
    SELECT 
        'PT' AS session_type,
        ps.start_time,
        ps.end_time,
        NULL::INT AS member_count,  
        ps.room_id
    FROM pt_sessions ps
    WHERE ps.trainer_id = p_trainer_id
    UNION ALL
    SELECT 
        'Class',
        cs.session_start,
        cs.session_end,
        (SELECT COUNT(*)::INT 
         FROM class_registrations cr 
         WHERE cr.session_id = cs.session_id),
        cs.room_id
    FROM class_sessions cs
    WHERE cs.trainer_id = p_trainer_id;

END;
$$;

-- this will look for member
CREATE OR REPLACE FUNCTION trainer_member_lookup(p_name VARCHAR)
RETURNS TABLE(member_id INT, full_name VARCHAR, last_weight NUMERIC, last_heart_rate INT, active_goals TEXT) 
AS $$
BEGIN
    RETURN QUERY
    SELECT u.user_id, u.full_name,
           (SELECT weight FROM health_metrics hm WHERE hm.member_id = u.user_id ORDER BY recorded_at DESC LIMIT 1),
           (SELECT heart_rate FROM health_metrics hm WHERE hm.member_id = u.user_id ORDER BY recorded_at DESC LIMIT 1),
           (SELECT STRING_AGG(goal_type || ' (' || target_value || ')', ', ')
            FROM fitness_goals fg WHERE fg.member_id = u.user_id AND (fg.target_date IS NULL OR fg.target_date >= current_date))
    FROM users u
    WHERE LOWER(u.full_name) LIKE LOWER('%' || p_name || '%') AND u.role = 'member';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION member_add_health_metric(p_member_id INT, p_weight NUMERIC, p_heart_rate INT)
RETURNS TEXT AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM members WHERE member_id = p_member_id) THEN
        RETURN 'member id ' || p_member_id || ' doesnt exist';
    END IF;
    INSERT INTO health_metrics(member_id, weight, heart_rate, recorded_at)
    VALUES (p_member_id, p_weight, p_heart_rate, now());
    RETURN 'health metric recorded successfully';
END;
$$ LANGUAGE plpgsql;

-- this will book a room
CREATE OR REPLACE FUNCTION admin_book_room(p_room_id INT, p_start timestamptz, p_end timestamptz) 
RETURNS TEXT AS $$
DECLARE
    conflict_count INT;
BEGIN
    IF p_start >= p_end THEN
        RETURN 'invalid time range';
    END IF;

    SELECT COUNT(*) INTO conflict_count
    FROM (
        SELECT session_start AS sstart, session_end AS send FROM class_sessions WHERE room_id = p_room_id
        UNION ALL
        SELECT start_time AS sstart, end_time AS send FROM pt_sessions WHERE room_id = p_room_id
    ) AS booked
    WHERE tstzrange(booked.sstart, booked.send, '[)') && tstzrange(p_start, p_end, '[)');

    IF conflict_count > 0 THEN
        RETURN 'sorry, the room is already booked';
    END IF;
    RETURN 'the room is available';
END;
$$ LANGUAGE plpgsql;


-- equipment mainteinance logging
CREATE OR REPLACE FUNCTION admin_log_equipment(p_equipment_id INT, p_room_id INT, p_reported_by INT, p_description TEXT)
RETURNS INT AS $$
DECLARE
    v_maintenance_id INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM equipment WHERE equipment_id = p_equipment_id) THEN
        RAISE EXCEPTION 'equipment id % doesnt exist.', p_equipment_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM rooms WHERE room_id = p_room_id) THEN
        RAISE EXCEPTION 'room id % doesnt exist.', p_room_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_reported_by) THEN
        RAISE EXCEPTION 'reporter user id % doesnt exist.', p_reported_by;
    END IF;
    INSERT INTO equipment_maintenance (equipment_id, room_id, reported_by, description, status)
    VALUES (p_equipment_id, p_room_id, p_reported_by, p_description, 'pending')
    RETURNING maintenance_id INTO v_maintenance_id;
    RETURN v_maintenance_id;
END;
$$ LANGUAGE plpgsql;

-- managing class
CREATE OR REPLACE FUNCTION admin_create_class(p_name VARCHAR, p_description TEXT, p_duration INT)
RETURNS INT AS $$
DECLARE
    new_class_id INT;
BEGIN
    INSERT INTO classes(name, description, duration_minutes)
    VALUES (p_name, p_description, p_duration)
    RETURNING class_id INTO new_class_id;

    RETURN new_class_id;
END;
$$ LANGUAGE plpgsql;
