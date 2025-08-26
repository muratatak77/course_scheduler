# Course / Room / Timeslot Scheduler -  Backtracking + simple pruning

A simple tool that creates schedules by assigning courses to rooms and time slots without conflicts, while trying to meet preferences.

---

* **Main algorithm** — `ScheduleSolver#solve`
* **Search method** — `ScheduleSolver#find_schedule`
* **Availability checks** — `ScheduleSolver#instructor_too_busy?`, `ScheduleSolver#can_schedule_here?`
* **Time management** — `ScheduleSolver#mark_time_busy`
* **Quality scoring** — `ScheduleSolver#calculate_score`
* **Web API** — `V1::ScheduleController#solve`

## What This Does

* Places each course in a room and a block of time
* Follows **must-have rules** (no conflicts, room size must fit class)
* Rewards **preferred conditions** (morning classes, avoid back-to-back teaching)
* Always gives the same result for the same input

---

## Input Data Needed

* **Rooms**: `{ id, capacity }`
* **Courses**: `{ id, duration_slots, required_capacity }`
* **Instructors**: `{ id, unavailable_slots[] }` (times when teacher can't teach)
* **total_slots** (optional): total time slots available, defaults to **48**

---

## How It Works

1. **`ScheduleSolver#solve`**
   Starts by sorting courses from hardest to easiest (big classes first, long classes first)

2. **`ScheduleSolver#find_schedule`**
   Tries every possible combination of room, teacher, and time for each course
   If it works, keeps going. If it fails, tries another option.

3. **`ScheduleSolver#instructor_too_busy?`**
   Skips teachers who are unavailable most of the time

4. **`ScheduleSolver#can_schedule_here?`**
   Checks if a room and teacher are free at the chosen time

5. **`ScheduleSolver#mark_time_busy`**
   Marks times as busy or free when assigning courses

6. **`ScheduleSolver#calculate_score`**
   Calculates how good the schedule is based on preferences

---

## Rules

### Must-Have Rules

* **No room double-booking** - Only one class per room at a time
* **No teacher overlap** - Teachers can't teach two classes at once
* **Room must fit class** - Room capacity must be ≥ class size

If any rule is broken, that option is rejected.

### Preferred Conditions (Affect Score)

* **Morning classes preferred** (`start_slot < 24`): **+1 point** per morning class
* **Avoid back-to-back teaching**: **-1 point** when same teacher has classes too close together

The final score adds up all these points. No randomness is used.

---

## How to Use the API

```
POST /v1/schedule/solve
Content-Type: application/json
```

**Send this data:**

```json
{
  "rooms": [
    { "id": "R1", "capacity": 30 },
    { "id": "R2", "capacity": 50 },
    { "id": "R3", "capacity": 20 }
  ],
  "courses": [
    { "id": "C1", "duration_slots": 2, "required_capacity": 25 },
    { "id": "C2", "duration_slots": 3, "required_capacity": 15 },
    { "id": "C3", "duration_slots": 1, "required_capacity": 40 }
  ],
  "instructors": [
    { "id": "I1", "unavailable_slots": [10, 11, 12] },
    { "id": "I2", "unavailable_slots": [15, 16] },
    { "id": "I3", "unavailable_slots": [] }
  ]
}
```

**You'll get back:**

```json
{
  "assignments": [
    { "course_id": "C3", "room_id": "R2", "instructor_id": "I1", "start_slot": 0, "end_slot": 0 },
    { "course_id": "C1", "room_id": "R1", "instructor_id": "I1", "start_slot": 1, "end_slot": 2 },
    { "course_id": "C2", "room_id": "R1", "instructor_id": "I1", "start_slot": 3, "end_slot": 5 }
  ],
  "score": 1,
  "unmetSoftConstraints": [
    "Instructor I1 has back-to-back courses",
    "Instructor I1 has back-to-back courses"
  ]
}
```

---

## Example Run with Sample Data

**Input used:**

```ruby
{
  rooms: [
    { id: 'R1', capacity: 30 },
    { id: 'R2', capacity: 50 },
    { id: 'R3', capacity: 20 }
  ],
  courses: [
    { id: 'C1', duration_slots: 2, required_capacity: 25 },
    { id: 'C2', duration_slots: 3, required_capacity: 15 },
    { id: 'C3', duration_slots: 1, required_capacity: 40 }
  ],
  instructors: [
    { id: 'I1', unavailable_slots: [10, 11, 12] },
    { id: 'I2', unavailable_slots: [15, 16] },
    { id: 'I3', unavailable_slots: [] }
  ]
}
```

**What happened:**

1. **Course C3** (40 students, 1 hour) → Room R2 (fits 50), Teacher I1, Time 0-0
2. **Course C1** (25 students, 2 hours) → Room R1 (fits 30), Teacher I1, Time 1-2
3. **Course C2** (15 students, 3 hours) → Room R1 (fits 30), Teacher I1, Time 3-5

**Scoring:**
- 3 morning classes: +3 points
- Teacher I1 has 2 back-to-back classes: -2 points
- **Final score: 1 point**

---

## Testing with curl

```bash
curl -X POST http://localhost:3000/v1/schedule/solve \
  -H 'Content-Type: application/json' \
  -d '{
    "rooms":[
      {"id":"R1","capacity":30},
      {"id":"R2","capacity":50},
      {"id":"R3","capacity":20}
    ],
    "courses":[
      {"id":"C1","duration_slots":2,"required_capacity":25},
      {"id":"C2","duration_slots":3,"required_capacity":15},
      {"id":"C3","duration_slots":1,"required_capacity":40}
    ],
    "instructors":[
      {"id":"I1","unavailable_slots":[10,11,12]},
      {"id":"I2","unavailable_slots":[15,16]},
      {"id":"I3","unavailable_slots":[]}
    ]
  }'
```

You'll get back the schedule with assignments, score, and any preference issues.

---

**Logs - Whats happening:**

```
Courses sorted: ["C3", "C1", "C2"]

-- ASSIGNMENTS (START) --
Trying course C3 (capacity 40, duration 1)

-- ASSIGNMENTS (before trying C3) --
  (none)
 Room R1 skipped (capacity 30 < 40)
 Room R2 ok (capacity 50)
    Instructor I1 candidate
      Assign -> {:course_id=>"C3", :room_id=>"R2", :instructor_id=>"I1", :start_slot=>0, :end_slot=>0, :duration=>0}

-- ASSIGNMENTS (after ASSIGN C3) --
  [0] {:course_id=>"C3", :room_id=>"R2", :instructor_id=>"I1", :start_slot=>0, :end_slot=>0, :duration=>0}

-- SCHEDULES (after ASSIGN C3) --
Rooms:
  Room R1:
   : ........ ........ ........ ........ ........ ........
  Room R2:
   : ■....... ........ ........ ........ ........ ........
  Room R3:
   : ........ ........ ........ ........ ........ ........
Instructors:
  Inst I1:
    : ■....... ........ ........ ........ ........ ........
  Inst I2:
    : ........ ........ ........ ........ ........ ........
  Inst I3:
    : ........ ........ ........ ........ ........ ........

  Trying course C1 (capacity 25, duration 2)

  -- ASSIGNMENTS (before trying C1) --
    [0] {:course_id=>"C3", :room_id=>"R2", :instructor_id=>"I1", :start_slot=>0, :end_slot=>0, :duration=>0}
   Room R1 ok (capacity 30)
     Instructor I1 candidate
       Reject CC1, RR1, II1, slots 0-1 — instructor busy at slot 0
       Assign -> {:course_id=>"C1", :room_id=>"R1", :instructor_id=>"I1", :start_slot=>1, :end_slot=>2, :duration=>1}

  -- ASSIGNMENTS (after ASSIGN C1) --
    [0] {:course_id=>"C3", :room_id=>"R2", :instructor_id=>"I1", :start_slot=>0, :end_slot=>0, :duration=>0}
    [1] {:course_id=>"C1", :room_id=>"R1", :instructor_id=>"I1", :start_slot=>1, :end_slot=>2, :duration=>1}

  -- SCHEDULES (after ASSIGN C1) --
    Rooms:
      Room R1:
      : .■■..... ........ ........ ........ ........ ........
      Room R2:
      : ■....... ........ ........ ........ ........ ........
      Room R3:
      : ........ ........ ........ ........ ........ ........
    Instructors:
      Inst I1:
        : ■■■..... ........ ........ ........ ........ ........
      Inst I2:
        : ........ ........ ........ ........ ........ ........
      Inst I3:
        : ........ ........ ........ ........ ........ ........

      Trying course C2 (capacity 15, duration 3)

    -- ASSIGNMENTS (before trying C2) --
      [0] {:course_id=>"C3", :room_id=>"R2", :instructor_id=>"I1", :start_slot=>0, :end_slot=>0, :duration=>0}
      [1] {:course_id=>"C1", :room_id=>"R1", :instructor_id=>"I1", :start_slot=>1, :end_slot=>2, :duration=>1}
     Room R1 ok (capacity 30)
       Instructor I1 candidate
         Reject CC2, RR1, II1, slots 0-2 — instructor busy at slot 0
         Reject CC2, RR1, II1, slots 1-3 — room busy at slot 1
         Reject CC2, RR1, II1, slots 2-4 — room busy at slot 2
         Assign -> {:course_id=>"C2", :room_id=>"R1", :instructor_id=>"I1", :start_slot=>3, :end_slot=>5, :duration=>2}

    -- ASSIGNMENTS (after ASSIGN C2) --
      [0] {:course_id=>"C3", :room_id=>"R2", :instructor_id=>"I1", :start_slot=>0, :end_slot=>0, :duration=>0}
      [1] {:course_id=>"C1", :room_id=>"R1", :instructor_id=>"I1", :start_slot=>1, :end_slot=>2, :duration=>1}
      [2] {:course_id=>"C2", :room_id=>"R1", :instructor_id=>"I1", :start_slot=>3, :end_slot=>5, :duration=>2}

    -- SCHEDULES (after ASSIGN C2) --
      Rooms:
        Room R1:
        : .■■■■■.. ........ ........ ........ ........ ........
        Room R2:
        : ■....... ........ ........ ........ ........ ........
        Room R3:
        : ........ ........ ........ ........ ........ ........
      Instructors:
        Inst I1:
          : ■■■■■■.. ........ ........ ........ ........ ........
        Inst I2:
          : ........ ........ ........ ........ ........ ........
        Inst I3:
          : ........ ........ ........ ........ ........ ........

        >> LEAF: all courses placed.

-- ASSIGNMENTS (LEAF depth=3) --
  [0] {:course_id=>"C3", :room_id=>"R2", :instructor_id=>"I1", :start_slot=>0, :end_slot=>0, :duration=>0}
  [1] {:course_id=>"C1", :room_id=>"R1", :instructor_id=>"I1", :start_slot=>1, :end_slot=>2, :duration=>1}
  [2] {:course_id=>"C2", :room_id=>"R1", :instructor_id=>"I1", :start_slot=>3, :end_slot=>5, :duration=>2}

      -- SCHEDULES (LEAF depth=3) --
      Rooms:
        Room R1:
         : .■■■■■.. ........ ........ ........ ........ ........
        Room R2:
         : ■....... ........ ........ ........ ........ ........
        Room R3:
         : ........ ........ ........ ........ ........ ........
      Instructors:
        Inst I1:
          : ■■■■■■.. ........ ........ ........ ........ ........
        Inst I2:
          : ........ ........ ........ ........ ........ ........
        Inst I3:
          : ........ ........ ........ ........ ........ ........

=== SCORING ===
Morning count = 3
Soft constraint violated: Instructor I1 has back-to-back courses
Soft constraint violated: Instructor I1 has back-to-back courses
Final Score = 1
Assignments:
  {:course_id=>"C3", :room_id=>"R2", :instructor_id=>"I1", :start_slot=>0, :end_slot=>0, :duration=>0}
  {:course_id=>"C1", :room_id=>"R1", :instructor_id=>"I1", :start_slot=>1, :end_slot=>2, :duration=>1}
  {:course_id=>"C2", :room_id=>"R1", :instructor_id=>"I1", :start_slot=>3, :end_slot=>5, :duration=>2}
```
---
