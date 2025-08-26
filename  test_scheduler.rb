# frozen_string_literal: true

# test_scheduler.rb
require 'json'
require 'net/http'
require 'uri'

def post_schedule(data)
  uri = URI.parse('http://localhost:3000/v1/schedule/solve')
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
  request.body = data.to_json
  response = http.request(request)
  puts "Status: #{response.code}"
  puts JSON.pretty_generate(JSON.parse(response.body))
  puts '-' * 50
end

# ----------------------------
# ✅ VALID CASE (should solve)
# ----------------------------
valid_data = {
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

# ----------------------------
# ❌ INVALID CASE (no room big enough for course)
# ----------------------------
invalid_data = {
  rooms: [
    { id: 'R1', capacity: 10 },
    { id: 'R2', capacity: 15 }
  ],
  courses: [
    { id: 'C1', duration_slots: 2, required_capacity: 30 }, # requires > any room
    { id: 'C2', duration_slots: 2, required_capacity: 12 }
  ],
  instructors: [
    { id: 'I1', unavailable_slots: [] }
  ]
}

puts '---- VALID TEST ----'
post_schedule(valid_data)

puts '---- INVALID TEST ----'
post_schedule(invalid_data)
