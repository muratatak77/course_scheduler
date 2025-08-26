# frozen_string_literal: true

module V1
  class ScheduleController < ApplicationController
    before_action :validate_input

    def solve
      # Create solver instance with validated inputs
      solver = ScheduleSolver.new(@rooms, @courses, @instructors, @total_slots)

      if solver.solve
        # Success: return assignments, score, and soft constraint notes
        render json: {
          assignments: solver.assignments.map(&:attributes),
          score: solver.score,
          unmetSoftConstraints: solver.unmet_soft_constraints
        }, status: :ok
      else
        # Failure: no valid schedule found
        render json: { error: 'No valid schedule found that satisfies all hard constraints' },
               status: :unprocessable_entity
      end
    end

    private

    # Strong params + build domain objects
    def validate_input
      data = if params[:schedule].present?
               params.require(:schedule).permit(
                 :total_slots,
                 rooms: %i[id capacity],
                 courses: %i[id duration_slots required_capacity],
                 instructors: [:id, { unavailable_slots: [] }]
               ).to_h
             else
               params.permit(
                 :total_slots,
                 rooms: %i[id capacity],
                 courses: %i[id duration_slots required_capacity],
                 instructors: [:id, { unavailable_slots: [] }]
               ).to_h
             end

      @total_slots = (data['total_slots'] || 48).to_i
      @rooms       = Array(data['rooms']).map       { |r| Room.new(r.to_h) }
      @courses     = Array(data['courses']).map     { |c| Course.new(c.to_h) }
      @instructors = Array(data['instructors']).map { |i| Instructor.new(i.to_h) }
    end
  end
end
