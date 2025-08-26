# frozen_string_literal: true

class Instructor < Base
  attribute :id, :string
  attribute :unavailable_slots, default: []

  validates :id, :unavailable_slots, presence: true
end
