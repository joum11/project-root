--users
INSERT INTO users (user_id, email, password_hash, full_name, date_of_birth, gender, phone, role)
VALUES
(1, 'john@handfc.com','hash', 'John Anderson', '1990-06-10', 'M', '613-617-1234', 'member'),
(2, 'finn@handfc.com', 'hash', 'Finn Byers', '1985-04-01', 'M', '613-617-2345', 'member'),
(3, 'carol@handfc.com', 'hash', 'Carol Shelby', '1992-11-11', 'F', '613-617-3456', 'member'),
(4, 'tommy@fit.com', 'hash', 'Tommy Flay', NULL, 'M', '613-617-4567', 'trainer'),
(5, 'sara@fit.com', 'hash', 'Sara Kimber',  NULL, 'F', '613-617-5678', 'trainer'),
(6, 'mark@fit.com', 'hash', 'Mark Lee', NULL, 'M', '613-617-8901', 'trainer'),
(7, 'abdullah@club.com', 'hash', 'Abdullah Joum', NULL, 'M', '613-617-6789', 'admin'),
(8, 'lisa@club.com', 'hash', 'Lisa Anker', '1995-02-20', 'F', '613-617-7890', 'admin'),
(9, 'billy@club.com', 'hash', 'Billy Locky', '1995-02-20', 'M', '613-617-0000', 'admin');

-- members
INSERT INTO members(member_id, emergency_contact)
VALUES
(1, 'Mother: 613-617-4321'),
(2, 'Wife: 613-617-5432'),
(3, 'Father: 613-617-6543');

-- trainers
INSERT INTO trainers (trainer_id, certification, specialization)
VALUES
(4, 'NASM', 'Weight loss'),
(5, 'ACE',  'Yoga'),
(6, 'ISSA', 'Strength training');

-- rooms
INSERT INTO rooms (room_id, name, capacity, description)
VALUES
(1, 'Studio A', 20, 'Large studio with mirrors'),
(2, 'Studio B', 12, 'Small studio'),
(3, 'PT Room 1', 1, 'Private training room'),
(4, 'PT Room 2', 1, 'Second private room'),
(5, 'Studio C', 15, 'Medium studio for classes');

-- equipment
INSERT INTO equipment (equipment_id, name, room_id, status)
VALUES
(1, 'Treadmill 1', 1, 'operational'),
(2, 'Elliptical Machine', 1, 'operational'),
(3, 'Bike Machine', 2, 'operational'),
(4, 'Rowing Machine', 1, 'operational'),
(5, 'Dumbbell Rack', 5, 'operational');

-- maintenance logs
INSERT INTO maintenance_logs (maintenance_id, equipment_id, room_id, reported_by, description, reported_at, status, resolved_at, resolver_id)
VALUES
(1, 1, 1, 6, 'The treadmill belt is noisy on high speed', '2025-11-25 10:15+00', 'open', NULL, NULL),
(2, 2, 1, 6, 'Elliptical is showing error E23', '2025-11-26 11:00+00', 'resolved', '2025-11-27 14:30+00', 6),
(3, 3, 2, 6, 'Bike chain needs oil', '2025-11-28 12:00+00', 'open', NULL, NULL),
(4, 4, 1, 6, 'Rowing machine foot strap broken', '2025-11-29 09:30+00', 'open', NULL, NULL),
(5, 5, 5, 6, 'Dumbbells misplaced', '2025-11-30 15:00+00', 'open', NULL, NULL);

--fitness goals
INSERT INTO fitness_goals (goal_id, member_id, goal_type, target_value, start_date, target_date)
VALUES
(1, 1, 'weight loss', 65, '2025-10-01', '2026-03-01'),
(2, 2, 'endurance', NULL, '2025-11-01', '2026-01-15'),
(3, 3, 'flexibility', NULL, '2025-10-15', '2026-02-15');

-- health metrics
INSERT INTO health_metrics (metric_id, member_id, weight, heart_rate, recorded_at)
VALUES
(1, 1, 72.5, 90, '2025-11-01 09:00+00'),
(2, 1, 71.8, 79, '2025-11-15 09:00+00'),
(3, 1, 68.0, 78, '2025-11-15 09:02+00'),
(4, 2, 80.0, 68, '2025-11-05 10:00+00'),
(5, 3, 65.2, 91, '2025-11-07 08:30+00');


-- classes
INSERT INTO classes (class_id, name, description, duration_minutes)
VALUES
(1, 'Zumba', 'Zumba Gold', 60),
(2, 'Yoga',  'Hatha Yoga', 45),
(3, 'Indoor Cycling',  'High intensity cycling', 45);

-- class sessions
INSERT INTO class_sessions (session_id, class_id, session_start, session_end, room_id, trainer_id, capacity)
VALUES
(1, 1, '2025-12-01 10:00+00', '2025-12-01 11:00+00', 1, 4, 15),
(2, 2, '2025-12-01 18:00+00', '2025-12-01 18:45+00', 2, 5, 10),
(3, 3, '2025-12-02 17:00+00', '2025-12-02 17:45+00', 1, 4, 12);


-- class registrations
INSERT INTO class_registrations (registration_id, session_id, member_id)
VALUES 
(1, 1, 1),
(2, 2, 2),
(3, 3, 3);

-- private trainers session
INSERT INTO pt_sessions (pt_session_id, member_id, trainer_id, start_time, end_time, room_id)
VALUES
(1, 1, 4, '2025-12-02 09:00+00', '2025-12-02 10:00+00', 3),
(2, 2, 5, '2025-12-03 16:30+00', '2025-12-03 17:30+00', 3),
(3, 3, 4, '2025-12-04 09:00+00', '2025-12-04 10:00+00', 3);


-- trainer availability
INSERT INTO trainer_availability (availability_id, trainer_id, available_start, available_end)
VALUES
(1, 4, '2025-12-02 08:00+00', '2025-12-02 12:00+00'),
(2, 4, '2025-12-03 14:00+00', '2025-12-03 18:00+00'),
(3, 5, '2025-12-01 16:00+00', '2025-12-01 19:00+00'),
(4, 6, '2025-12-05 10:00+00', '2025-12-05 13:00+00');


-- invoices
INSERT INTO invoices (invoice_id, member_id, due_date, total_amount, status)
VALUES
(1, 1, '2025-11-01 09:00+00', 100.00, 'unpaid'),
(2, 2, '2025-11-01 09:10+00', 75.00, 'unpaid'),
(3, 3, '2025-11-05 12:00+00', 120.00, 'unpaid');

-- invoice items
INSERT INTO invoice_items (item_id, invoice_id, description, amount)
VALUES
(1, 1, 'Monthly membership', 50.00),
(2, 2, 'PT session x1', 50.00),
(3, 3, 'Monthly membership', 75.00);

-- payments
INSERT INTO payments (payment_id, invoice_id, paid_at, amount, method)
VALUES
(1, 2, '2025-11-05 14:00+00', 75.00, 'credit_card'),
(2, 3, '2025-11-06 10:00+00', 120.00, 'cash'),
(3, 1, '2025-11-12 09:30+00', 90.00, 'credit_card');