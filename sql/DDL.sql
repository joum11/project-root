CREATE EXTENSION IF NOT EXISTS btree_gist;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('member', 'trainer', 'admin');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'gender_type') THEN
    CREATE TYPE gender_type AS ENUM ('M','F','O');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'maintenance_status') THEN
    CREATE TYPE maintenance_status AS ENUM ('open','resolved','in_progress');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'equipment_status') THEN
    CREATE TYPE equipment_status AS ENUM ('operational','maintenance');
  END IF;
END$$;

-- users
CREATE TABLE users (user_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, email VARCHAR(255) NOT NULL UNIQUE, password_hash VARCHAR(255) NOT NULL, full_name VARCHAR(100) NOT NULL, date_of_birth DATE, gender gender_type, phone VARCHAR(20), role user_role NOT NULL, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now());

-- members
CREATE TABLE members (
  member_id INT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE, emergency_contact VARCHAR(255) NOT NULL);

-- trainers
CREATE TABLE trainers (trainer_id INT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE, certification VARCHAR(100), specialization VARCHAR(100));

-- rooms
CREATE TABLE rooms (room_id SERIAL PRIMARY KEY, name VARCHAR(50) NOT NULL, capacity INT NOT NULL CHECK (capacity > 0), description TEXT);

-- eqiupment
CREATE TABLE equipment (equipment_id SERIAL PRIMARY KEY, name VARCHAR(50) NOT NULL, room_id INT REFERENCES rooms(room_id) ON DELETE SET NULL, status equipment_status DEFAULT 'operational');

-- maintenance logs
CREATE TABLE maintenance_logs (maintenance_id SERIAL PRIMARY KEY, equipment_id INT REFERENCES equipment(equipment_id) ON DELETE CASCADE, room_id INT REFERENCES rooms(room_id) ON DELETE CASCADE, reported_by INT REFERENCES users(user_id), description TEXT NOT NULL, reported_at timestamptz NOT NULL DEFAULT now(), status maintenance_status DEFAULT 'open', resolved_at timestamptz, resolver_id INT REFERENCES users(user_id), CHECK ((status = 'resolved' AND resolved_at IS NOT NULL) OR status <> 'resolved'));

-- maintenance audit
CREATE TABLE maintenance_audit (audit_id SERIAL PRIMARY KEY, maintenance_id INT REFERENCES maintenance_logs(maintenance_id) ON DELETE CASCADE, old_status maintenance_status, new_status maintenance_status, changed_at timestamptz NOT NULL DEFAULT now(), changed_by INT REFERENCES users(user_id));

-- this will trigger for maintenance audit
CREATE OR REPLACE FUNCTION audit_maintenance_status() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO maintenance_audit(maintenance_id, old_status, new_status, changed_at, changed_by)
    VALUES (OLD.maintenance_id, OLD.status, NEW.status, now(), NEW.resolver_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_maintenance_audit
AFTER UPDATE OF status ON maintenance_logs
FOR EACH ROW EXECUTE FUNCTION audit_maintenance_status();

-- fitness goals
CREATE TABLE fitness_goals (goal_id SERIAL PRIMARY KEY, member_id INT REFERENCES members(member_id) ON DELETE CASCADE, goal_type VARCHAR(50), target_value NUMERIC CHECK (target_value IS NULL OR target_value > 0), start_date DATE, target_date DATE);
ALTER TABLE fitness_goals
ADD CONSTRAINT unique_member_goal UNIQUE (member_id, goal_type);

-- health metrics
 CREATE TABLE health_metrics (metric_id SERIAL PRIMARY KEY, member_id INT REFERENCES members(member_id) ON DELETE CASCADE, weight NUMERIC CHECK (weight > 0), heart_rate INT CHECK (heart_rate > 0), recorded_at timestamptz NOT NULL CHECK (recorded_at <= now()));
-- classes
CREATE TABLE classes (class_id SERIAL PRIMARY KEY, name VARCHAR(50) NOT NULL, description TEXT, duration_minutes INT CHECK (duration_minutes > 0));

-- class sessions
CREATE TABLE class_sessions (sessioPAn_id SERIAL PRIMARY KEY, class_id INT REFERENCES classes(class_id) ON DELETE CASCADE, session_start timestamptz NOT NULL, session_end timestamptz NOT NULL, room_id INT REFERENCES rooms(room_id) ON DELETE CASCADE, trainer_id INT REFERENCES trainers(trainer_id) ON DELETE CASCADE, capacity INT NOT NULL CHECK (capacity > 0), CHECK (session_start < session_end));

--this will trigger the function to prevent the overlapping of class sessions
CREATE OR REPLACE FUNCTION check_class_overlap() RETURNS trigger AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM class_sessions
    WHERE room_id = NEW.room_id
      AND tstzrange(session_start, session_end, '[]') &&
          tstzrange(NEW.session_start, NEW.session_end, '[]')
      AND session_id <> NEW.session_id
  ) THEN
    RAISE EXCEPTION 'sorry, the room already has a overlapping session';
  END IF;
  IF EXISTS (
    SELECT 1 FROM class_sessions
    WHERE trainer_id = NEW.trainer_id
      AND tstzrange(session_start, session_end, '[]') &&
          tstzrange(NEW.session_start, NEW.session_end, '[]')
      AND session_id <> NEW.session_id
  ) THEN
    RAISE EXCEPTION 'sorry, the trainer already has an overlapping session';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql; 
CREATE TRIGGER trg_check_class_overlap
BEFORE INSERT OR UPDATE ON class_sessions
FOR EACH ROW EXECUTE FUNCTION check_class_overlap();

-- class registration
CREATE TABLE class_registrations (registration_id SERIAL PRIMARY KEY, session_id INT REFERENCES class_sessions(session_id) ON DELETE CASCADE, member_id INT REFERENCES members(member_id) ON DELETE CASCADE, UNIQUE(session_id, member_id));

-- private trainer sessions
CREATE TABLE pt_sessions (pt_session_id SERIAL PRIMARY KEY, member_id INT REFERENCES members(member_id) ON DELETE CASCADE, trainer_id INT REFERENCES trainers(trainer_id) ON DELETE CASCADE, start_time timestamptz NOT NULL, end_time timestamptz NOT NULL, room_id INT REFERENCES rooms(room_id) ON DELETE CASCADE, CHECK (start_time < end_time));

-- this will trigger the function to prevent the overlapp og PT sessions
CREATE OR REPLACE FUNCTION check_pt_overlap() RETURNS trigger AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pt_sessions
    WHERE room_id = NEW.room_id
      AND tstzrange(start_time, end_time, '[]') &&
          tstzrange(NEW.start_time, NEW.end_time, '[]')
      AND pt_session_id <> NEW.pt_session_id
  ) THEN
    RAISE EXCEPTION 'sorry, room already booked';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pt_sessions
    WHERE trainer_id = NEW.trainer_id
      AND tstzrange(start_time, end_time, '[]') &&
          tstzrange(NEW.start_time, NEW.end_time, '[]')
      AND pt_session_id <> NEW.pt_session_id
  ) THEN
    RAISE EXCEPTION 'sorry, private trainer already booked';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_check_pt_overlap
BEFORE INSERT OR UPDATE ON pt_sessions
FOR EACH ROW EXECUTE FUNCTION check_pt_overlap();

 -- trainer availability
CREATE TABLE trainer_availability ( availability_id SERIAL PRIMARY KEY, trainer_id INT REFERENCES trainers(trainer_id) ON DELETE CASCADE, available_start timestamptz NOT NULL, available_end timestamptz NOT NULL, CHECK (available_start < available_end));

-- invoices
CREATE TABLE invoices (invoice_id SERIAL PRIMARY KEY, member_id INT REFERENCES members(member_id) ON DELETE CASCADE, due_date timestamptz NOT NULL, total_amount NUMERIC CHECK (total_amount >= 0), status VARCHAR(20) DEFAULT 'unpaid');

-- invoice items
CREATE TABLE invoice_items (item_id SERIAL PRIMARY KEY, invoice_id INT REFERENCES invoices(invoice_id) ON DELETE CASCADE, description TEXT NOT NULL, amount NUMERIC CHECK (amount > 0));

-- payments
CREATE TABLE payments (payment_id SERIAL PRIMARY KEY, invoice_id INT REFERENCES invoices(invoice_id) ON DELETE CASCADE, paid_at timestamptz NOT NULL, amount NUMERIC CHECK (amount > 0), method VARCHAR(50) NOT NULL);
