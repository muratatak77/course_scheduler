# frozen_string_literal: true

class Assignment < Base
  attribute :course_id, :string
  attribute :room_id, :string
  attribute :instructor_id, :string
  attribute :start_slot, :integer
  attribute :end_slot, :integer

  def duration
    end_slot - start_slot
  end

  def to_h
    {
      course_id: course_id,
      room_id: room_id,
      instructor_id: instructor_id,
      start_slot: start_slot,
      end_slot: end_slot,
      duration: duration
    }
  end
end
