# frozen_string_literal: true

# Finds a schedule for courses in rooms and timeslots
class ScheduleSolver
  attr_accessor :assignments, :score, :unmet_soft_constraints

  MORNING_CUTOFF  = 24
  TOO_BUSY_RATIO  = 0.80

  # Setup the solver with rooms, courses, instructors and total time slots
  def initialize(rooms, courses, instructors, total_slots = 48)
    @rooms        = Array(rooms)
    @courses      = Array(courses)
    @instructors  = Array(instructors)
    @total_slots  = Integer(total_slots)

    @assignments            = []
    @score                  = 0
    @unmet_soft_constraints = []

    # simple busy bitmaps (room_id/instructor_id -> [true/false] per slot)
    @room_busy       = Hash.new { |h, k| h[k] = Array.new(@total_slots, false) }
    @instructor_busy = Hash.new { |h, k| h[k] = Array.new(@total_slots, false) }

    # keep unavailability as Set so lookups are O(1) — might revisit later
    @instructor_unavail = {}
    @instructors.each do |ins|
      list = ins.respond_to?(:unavailable_slots) ? (ins.unavailable_slots || []) : []
      @instructor_unavail[ins.id] = list.to_set
    end
  end

  # Try to find a schedule that works
  # Returns true if found, false if not possible
  def solve
    # put harder courses first (bigger + longer) — heuristic, not perfect
    sorted_courses = @courses.sort_by { |c| [-c.required_capacity.to_i, -c.duration_slots.to_i] }

    if find_schedule(sorted_courses, 0)
      calculate_score
      true
    else
      false
    end
  end

  private

  # Backtracking search over courses/rooms/instructors/time
  def find_schedule(courses, course_index)
    return true if course_index >= courses.length

    course = courses[course_index]

    @rooms.each do |room|
      next if room.capacity.to_i < course.required_capacity.to_i

      @instructors.each do |instructor|
        next if instructor_too_busy?(instructor) # maybe make this tunable later

        last_start = @total_slots - course.duration_slots.to_i
        next if last_start.negative?

        0.upto(last_start) do |start_slot|
          end_slot = start_slot + course.duration_slots - 1

          ok, = can_schedule_here?(room, instructor, start_slot, end_slot)
          next unless ok

          # NOTE: Assignment is assumed to be a simple data holder
          assignment = Assignment.new(
            course_id: course.id,
            room_id: room.id,
            instructor_id: instructor.id,
            start_slot: start_slot,
            end_slot: end_slot
          )

          @assignments << assignment
          mark_time_busy(room, instructor, start_slot, end_slot, true)

          return true if find_schedule(courses, course_index + 1)

          # backtrack — might want to track reasons later
          @assignments.pop
          mark_time_busy(room, instructor, start_slot, end_slot, false)
        end
      end
    end

    false
  end

  # treat instructors with too many blocked slots as "skip for now"
  def instructor_too_busy?(instructor)
    slots = @instructor_unavail[instructor.id]
    return false unless slots # if no info, don't punish

    slots.size > (@total_slots * TOO_BUSY_RATIO)
  end

  # room/instructor must be free and instructor not unavailable — pretty literal check
  def can_schedule_here?(room, instructor, start_slot, end_slot)
    ins_unavail = @instructor_unavail[instructor.id] || Set.new

    start_slot.upto(end_slot) do |slot|
      return [false, "room busy at #{slot}"]            if @room_busy[room.id][slot]
      return [false, "instructor busy at #{slot}"]      if @instructor_busy[instructor.id][slot]
      return [false, "instructor unavailable at #{slot}"] if ins_unavail.include?(slot)
    end

    [true, nil]
  end

  # flip busy flags for the chosen span — not the most compact, but clear enough
  def mark_time_busy(room, instructor, start_slot, end_slot, is_busy)
    start_slot.upto(end_slot) do |slot|
      @room_busy[room.id][slot] = is_busy
      @instructor_busy[instructor.id][slot] = is_busy
    end
  end

  # simplistic scoring: reward mornings, penalize tight back-to-back
  def calculate_score
    @score = 0
    @unmet_soft_constraints = []

    morning = @assignments.count { |a| a.start_slot < MORNING_CUTOFF }
    @score += morning

    # maybe make this threshold configurable
    if @assignments.any? && morning < (@assignments.length * 0.5)
      @unmet_soft_constraints << 'Less than half of classes are in the morning'
    end

    # back-to-back penalty (gap <= 1). could add weight later
    @assignments.group_by(&:instructor_id).each_value do |blocks|
      blocks.sort_by!(&:start_slot)
      blocks.each_cons(2) do |a, b|
        gap = b.start_slot - a.end_slot
        next unless gap <= 1

        @score -= 1
        @unmet_soft_constraints << "Instructor #{a.instructor_id} has classes too close together"
      end
    end
  end
end
