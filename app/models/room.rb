# frozen_string_literal: true

class Room < Base
  attribute :id, :string
  attribute :capacity, :integer

  validates :id, :capacity, presence: true
end
