# frozen_string_literal: true

class Course < Base
  attribute :id, :string
  attribute :duration_slots, :integer
  attribute :required_capacity, :integer

  validates :id, :duration_slots, :required_capacity, presence: true
end
