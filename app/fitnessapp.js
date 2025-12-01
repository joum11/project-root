// student name: Abdullah joumani
// student id: 101309229
const { Client } = require("pg");
const prompt = require("prompt-sync")({ sigint: true });

//postgres configuration to have a connection
const client = new Client({
  user: "postgres",
  host: "localhost",
  database: "Project",
  password: "J2005",
  port: 5432,
});
async function safeQuery(sql, params = []) {
  try {
    const res = await client.query(sql, params);
    return { ok: true, data: res.rows };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

// thiese will make sure input is there
function makesure(question, validator) {
  while (true) {
    const raw = prompt(question);
    if (raw === null || raw.trim().toLowerCase() === "cancel") return null;
    const value = raw.trim();
    const check = validator(value);
    if (check.ok) return check.value;
    console.log(check.error);
  }
}
const makesurenotempty = v =>
  v ? { ok: true, value: v } : { ok: false, error: "the input cannot be empty." };

const validateOptional = v => ({ ok: true, value: v || null });
// this function for gender input
const validateGender = v => {
  const g = v.toLowerCase();
  if (["m", "male", "man"].includes(g)) return { ok: true, value: "M" };
  if (["f", "female", "woman"].includes(g)) return { ok: true, value: "F" };
  if (["o", "other"].includes(g)) return { ok: true, value: "O" };
  return { ok: false, error: "enter male or female or other." };
};
// date format should be right
function validateDate(v) {
  const r = /^\d{4}-\d{2}-\d{2}$/;
  if (!r.test(v)) return { ok: false, error: "the date must be YYYY-MM-DD." };
  if (isNaN(new Date(v))) return { ok: false, error: "invalid date." };
  return { ok: true, value: v };
}
// time should be in the correct format
function validateTimestamp(v) {
  if (isNaN(Date.parse(v)))
    return { ok: false, error: "invalid timestampm, must be in YYYY-MM-DD HH:MM" };
  return { ok: true, value: v };
}
// checks integer is inputed 
function validateInt(v) {
  const n = Number(v);
  if (!Number.isInteger(n)) return { ok: false, error: "not a valid integer." };
  return { ok: true, value: n };
}
// checks positive integer is inputed 
function validatePositive(v) {
  const n = Number(v);
  if (isNaN(n) || n <= 0) return { ok: false, error: "enter a positive number." };
  return { ok: true, value: n };
}
// results
function printResult(result) {
  if (!result.ok) {
    console.log("database Error:", result.error);
    return;
  }
  if (!result.data || result.data.length === 0) {
    console.log("(empty result)");
  } else {
    console.table(result.data);
  }
}
// checks if a member exists
async function memberExists(memberId) {
  const q = await safeQuery("SELECT 1 FROM members WHERE member_id = $1", [memberId]);
  return q.ok && q.data.length > 0;
}
//checks if a trainer exists
async function trainerExists(trainerId) {
  const q = await safeQuery(
    "SELECT 1 FROM users WHERE user_id = $1 AND role = 'trainer'",
    [trainerId]
  );
  return q.ok && q.data.length > 0;
}
//checks if a room exists
async function roomExists(roomId) {
  const q = await safeQuery("SELECT 1 FROM rooms WHERE room_id = $1", [roomId]);
  return q.ok && q.data.length > 0;
}
//checks if a email exists
async function emailExists(email) {
  const q = await safeQuery("SELECT 1 FROM users WHERE email = $1", [email]);
  return q.ok && q.data.length > 0;
}

// this will register a member
async function registerMember() {
  console.log("\nRegister New Member");
  let email = makesure("Email: ", makesurenotempty);
  if (!email) return;
  while (await emailExists(email)) {
    console.log("the email already exists. Enter another email.");
    email = makesure("Email: ", makesurenotempty);
  }
  const password = makesure("Password: ", makesurenotempty);
  const full = makesure("Full Name: ", makesurenotempty);
  const dob = makesure("DOB (YYYY-MM-DD): ", validateDate);
  const gender = makesure("Gender (M/F/O): ", validateGender);
  const phone = makesure("Phone: ", makesurenotempty);
  const emergency = makesure("Emergency Contact: ", makesurenotempty);
  const q = await safeQuery(
    "SELECT member_register($1,$2,$3,$4,$5,$6,$7) AS member_id",
    [email, password, full, dob, gender, phone, emergency]
  );
  if (!q.ok) return printResult(q);
  if (q.data[0].member_id) console.log("member registered with ID:", q.data[0].member_id);
  else console.log("member not created the email already exists.");
}
// this will update the profile info
async function updateProfile() {
  console.log("\nUpdate Member Profile");
  const memberId = makesure("Member ID: ", validateInt);
  if (!memberId) return;
  if (!await memberExists(memberId)) {
    console.log("no member exist with this ID.");
    return;
  }
  const full = makesure("New Full Name: ", makesurenotempty);
  const phone = makesure("Phone: ", makesurenotempty);
  const goalType = makesure("Goal type: ", validateOptional);
  const targetValue = makesure("Target value: ", validateOptional);
  const profileUpdate = await safeQuery(
    "SELECT member_update_profile($1,$2,$3,$4,$5) AS status",
    [memberId, full, phone, goalType, targetValue]
  );
  console.log(profileUpdate.ok ? profileUpdate.data[0].status : "Database Error: " + profileUpdate.error);
  const logMetric = makesure("Do you want to log a new health metric, yes or no?: ", v => {
    const val = v.toLowerCase();
    if (["y","yes"].includes(val)) return { ok: true, value: true };
    if (["n","no"].includes(val)) return { ok: true, value: false };
    return { ok: false, error: "please enter y/yes or n/no" };
  });
  if (logMetric) {
    await addHealthMetric(memberId);
  }
}

// this is for halth history
async function addHealthMetric(memberIdArg = null) {
  console.log("\nAdd Health Metric");
  const memberId = memberIdArg || makesure("Member ID: ", validateInt);
  if (!memberId) return;
  if (!await memberExists(memberId)) {
    console.log("no member exists with this ID.");
    return;
  }
  const weight = makesure("Weight (kg): ", validatePositive);
  const heartRate = makesure("Heart Rate (bpm): ", validateInt);
  const recordedAt = makesure("Recorded at (YYYY-MM-DD HH:MM) or leave empty: ", v => {
    if (!v) return { ok: true, value: new Date().toISOString() };
    const parsed = Date.parse(v);
    if (isNaN(parsed)) return { ok: false, error: "Invalid timestamp format." };
    return { ok: true, value: new Date(parsed).toISOString() };
  });
  const q = await safeQuery(
    `INSERT INTO health_metrics(member_id, weight, heart_rate, recorded_at)
     VALUES($1, $2, $3, $4)
     RETURNING metric_id, recorded_at`,
    [memberId, weight, heartRate, recordedAt]
  );
  if (!q.ok) {
    console.log("database Error:", q.error);
  } else {
    console.log(`health metric logged with ID ${q.data[0].metric_id} at ${q.data[0].recorded_at}`);
  }
}
// this will schedule private trainer seesion
async function schedulePT() {
  console.log("\nSchedule PT Session");
  const mid = makesure("Member ID: ", validateInt);
  if (mid === null) return;
  if (!await memberExists(mid)) {
    console.log("no member exists with this ID.");
    return;
  }
  const tid = makesure("Trainer ID: ", validateInt);
  if (!await trainerExists(tid)) {
    console.log("no trainer exists with this ID.");
    return;
  }
  const rid = makesure("Room ID: ", validateInt);
  if (!await roomExists(rid)) {
    console.log("no room exists with this ID.");
    return;
  }
  const start = makesure("Start (YYYY-MM-DD HH:MM): ", validateTimestamp);
  const end = makesure("End (YYYY-MM-DD HH:MM): ", validateTimestamp);
  const q = await safeQuery(
    "SELECT member_schedule_pt($1,$2,$3,$4,$5) AS status",
    [mid, tid, rid, start, end]
  );
  if (!q.ok) console.log("database Error:", q.error);
  else console.log(q.data[0].status);
}

async function registerClass() {
  console.log("\nRegister for Class");

  const mid = makesure("Member ID: ", validateInt);
  if (!mid) return;
  if (!await memberExists(mid)) return console.log("member does not exist.");
  const sid = makesure("class Session ID: ", validateInt);
  if (!sid) return;
  const q = await safeQuery(
    "SELECT member_register_class($1,$2) AS status",
    [mid, sid]
  );
  console.log(q.ok ? q.data[0].status : "database Error: " + q.error);
}

// this will set the trainer for availability
async function trainerSetAvailability() {
  console.log("\nTrainer: Set Availability");
  const tid = makesure("Trainer ID: ", validateInt);
  if (tid === null) return;
  if (!await trainerExists(tid)) {
    console.log("no trainer exists with this ID.");
    return;
  }
  const start = makesure("Start (YYYY-MM-DD HH:MM): ", validateTimestamp);
  const end = makesure("End (YYYY-MM-DD HH:MM): ", validateTimestamp);
  const q = await safeQuery(
    "SELECT trainer_set_availability($1,$2,$3) AS status",
    [tid, start, end]
  );
  if (!q.ok) console.log("database Error:", q.error);
  else console.log(q.data[0].status);
}
// this will view trainer schedule 
async function trainerViewSchedule() {
  console.log("\nTrainer: View Schedule");
  const tid = makesure("Trainer ID: ", validateInt);
  if (!tid) return;
  if (!await trainerExists(tid)) return console.log("trainer does not exist.");
  const q = await safeQuery("SELECT * FROM trainer_schedule_view($1)", [tid]);
  printResult(q);
}
async function trainerMemberLookup() {
  console.log("\nTrainer: Member Lookup");
  console.log("Search by member name to view:");
  console.log("Current goals");
  console.log("Last recorded weight and heart rate");
  const name = makesure("Enter full or partial name: ", makesurenotempty);
  if (name === null) return;
  const q = await safeQuery(
    "SELECT * FROM trainer_member_lookup($1)",
    [name]
  );
  printResult(q);
}
// this will book a room 
async function adminBookRoom() {
  console.log("\nCheck Room Availability");
  console.log("Enter room ID and the time range you want to check.");
  console.log("Format: YYYY-MM-DD HH:MM");
  const rid = makesure("Room ID: ", validateInt);
  if (rid === null) return;
  if (!await roomExists(rid)) {
    console.log("no room exists with this ID.");
    return;
  }
  const start = makesure("Start (YYYY-MM-DD HH:MM): ", validateTimestamp);
  const end = makesure("End (YYYY-MM-DD HH:MM): ", validateTimestamp);
  const q = await safeQuery(
    "SELECT admin_book_room($1,$2,$3) AS status",
    [rid, start, end]
  );
  if (!q.ok) console.log("database Error:", q.error);
  else console.log(q.data[0].status);
}
// admin will log issues in equipments 
async function adminLogEquipment() {
  console.log("\nEquipment Maintenance");
  console.log("Options:");
  console.log("1) Log a new issue");
  console.log("2) View all issues");
  const choice = makesure("Choose option: ", v => {
    if (["1","2"].includes(v)) return { ok: true, value: v };
    return { ok: false, error: "Enter 1 or 2" };
  });
  if (choice === "1") {
    const eq = makesure("Equipment ID: ", validateInt);
    if (!eq) return;
    const room = makesure("Room ID: ", validateInt);
    const rep = makesure("Reported By (User ID): ", validateInt);
    const desc = makesure("Description: ", makesurenotempty);
    const q = await safeQuery(
      "SELECT admin_log_equipment($1,$2,$3,$4) AS maintenance_id",
      [eq, room, rep, desc]
    );
    console.log(q.ok ? "Maintenance logged with ID: " + q.data[0].maintenance_id 
                      : "Database Error: " + q.error);
  } else if (choice === "2") {
    const q = await safeQuery(
        "SELECT maintenance_id, equipment_id, room_id, reported_by, description, status FROM equipment_maintenance ORDER BY maintenance_id DESC"
    );
    printResult(q);
    console.log(q.ok ? q.data[0].result : "database Error: " + q.error);
  }
}
// this will create a class
async function adminCreateClass() {
  console.log("\nCreate Class");
  const name = makesure("Class name: ", makesurenotempty);
  if (!name) return;
  const desc = makesure("Description: ", makesurenotempty);
  const dur = makesure("Duration in minutes: ", v => {
    const n = Number(v);
    if (!Number.isInteger(n) || n <= 0) return { ok: false, error: "enter a positive integer." };
    return { ok: true, value: n };
    });
  const q = await safeQuery(
    "SELECT admin_create_class($1,$2,$3) AS class_id",
    [name, desc, dur]
    );
  console.log(q.ok ? "Class created with ID: " + q.data[0].class_id : "database Error: " + q.error);
}

const menu = {
  1: registerMember,
  2: updateProfile,
  3: addHealthMetric,
  4: schedulePT,
  5: registerClass,
  6: trainerSetAvailability,
  7: trainerViewSchedule,
  8: trainerMemberLookup,
  9: adminBookRoom,
  10: adminLogEquipment,
  11: adminCreateClass,
};
// this function will connect to postgres
async function main() {
  try {
    await client.connect();
    console.log("connected to PostgreSQL.");
  } catch (err) {
    console.log("unable to connect:", err.message);
    return;
  }

// this will ask user role at start their role
  const role = makesure("Enter your role member or trainer or admin: ", v => {
    const r = v.toLowerCase();
    if (["member","trainer","admin"].includes(r)) return { ok: true, value: r };
    return { ok: false, error: "enter member or trainer or admin." };
  });
  const allowedFunctions = {
    member: [1,2,3,4,5],
    trainer: [6,7,8],
    admin: [9,10,11]
  }[role];
// the user will see
  while (true) {
    console.log("\n Menu");
    console.log("1) Register Member");
    console.log("2) Update Profile");
    console.log("3) Add Health Metric");
    console.log("4) Schedule PT");
    console.log("5) Register for Class");
    console.log("6) Trainer: Set Availability");
    console.log("7) Trainer: View Schedule");
    console.log("8) Trainer: Member Lookup");
    console.log("9) Admin: Book Room");
    console.log("10) Admin: Equipment Maintenance");
    console.log("11) Admin: Class Management");
    console.log("12) Exit");

    const choice = prompt("Choose an option: ").trim();
    if (choice === "12") break;
    const choiceNum = Number(choice);
    if (!allowedFunctions.includes(choiceNum)) {
      console.log("sorry, you do not have permission to use this function.");
      continue;
    }
    const action = menu[choice];
    if (action) await action();
    else console.log("invalid option, please try again.");
  }
  await client.end();
  console.log("disconnected.");
}

main();
