Student Name: Abdullah Joumani
Student ID: 101309229

I implemented a health and fitness club management system using PostgreSQL for database management, and javascript file "fitnessapp.js" for the backend. so this application runs on the machine without using postgres directly, it just connects to it using "Node.js". 
When using this application you can 
manage members "register or update profile, track health metrics with timestamps".
manage classes "create classes, assign trainers, rooms,  update schedules". 
manage trainers "set availability, view schedule,  look up member information".
manage health history "store multiple health metric entries".
manage equipment maintenance "log equipment issues, track repair status, associate issues with rooms".
by doing the following "you can check the video uploaded within the submission": 

1. by using terminal, navigate to the folder that contains the fitnessapp.js file
2. you should have Node.js, PostgreSQL, pgAdmin 4, and npm packages "pg and prompt-sync" if not run the following npm install pg prompt-sync.
3. type: node fitnessapp.js 
4. you will get a message "connected to postgres successfully" that confirms that you have been connected to postgres. "you might need to update the password of the user"
5. you will then get the following after selecting your role (member or trainer or admin) because some roles cannot access certain functions:
 Menu
1) Register Member
2) Update Profile
3) Add Health Metric
4) Schedule PT
5) Register for Class
6) Trainer: Set Availability
7) Trainer: View Schedule
8) Trainer: Member Lookup
9) Admin: Book Room
10) Admin: Equipment Maintenance
11) Admin: Class Management
12) Exit

from 1 to 5 for members, from 6 to 8 for trainers, from 9 to 11 for admins. 12 to exit

6. typing 1 will allow members to register a member, typing 2 will allow you to update an existing profile, typing 3 will allow you to add health metrics with memory, typing 4 will allow you to schedule private trainer session, typing 5 will allow you to register for a class, typing 6 will allow you to set availability for trainers, typing 7 will allow you to view the schedule of the trainer, typing 8 will allow you to look for members, typing 9 will allow you as an admin to book a room, typing 10 will allow you as an admin to log issues or track the repair status og an equipment, typing 11 will allow you to create classes, typing 12 terminate the application. 

Must haves:
PostgresSQL
pgAdmin 4
Node.js
npm packages "pg and prompt-sync"

video link: https://drive.google.com/file/d/1v7zinChSBk-fv1rlC7iHJ6-Cb0FscRKv/view?usp=sharing
