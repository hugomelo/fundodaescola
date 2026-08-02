module Api
  module Admin
    class TripsController < BaseController
      # GET /api/admin/grades/:grade_id/trips
      def index
        grade = find_grade!
        render json: {
          inflation_rate: grade.inflation_rate,
          trips: grade.trips.ordered.map { |t| trip_json(t, grade) }
        }
      end

      # POST /api/admin/grades/:grade_id/trips
      def create
        grade = find_grade!
        trip = grade.trips.new(trip_params)
        trip.position ||= (grade.trips.maximum(:position) || 0) + 1
        trip.save!
        # Optional base cost entry supplied inline.
        if params.dig(:trip, :base_amount_cents).present? && params.dig(:trip, :base_year).present?
          trip.cost_entries.create!(year: params[:trip][:base_year], amount_cents: params[:trip][:base_amount_cents])
        end
        render json: { trip: trip_json(trip, grade) }, status: :created
      end

      # PATCH /api/admin/trips/:id
      def update
        trip = find_trip!
        trip.update!(trip_params)
        render json: { trip: trip_json(trip, trip.grade) }
      end

      # DELETE /api/admin/trips/:id
      def destroy
        find_trip!.destroy!
        head :no_content
      end

      private

      def find_trip!
        trip = Trip.find(params[:id])
        authorize!(current_user.can_admin_grade?(trip.grade_id))
        trip
      end

      def trip_json(trip, grade)
        {
          id: trip.id,
          grade_id: trip.grade_id,
          name: trip.name,
          level: trip.level,
          trip_year: trip.trip_year,
          position: trip.position,
          cost_cents: trip.cost_cents_for(trip.trip_year, grade.inflation_rate.to_f),
          is_actual: trip.actual_for_trip_year?,
          entries: trip.cost_entries.order(:year).map { |e| { id: e.id, year: e.year, amount_cents: e.amount_cents } }
        }
      end

      def trip_params
        params.require(:trip).permit(:name, :level, :trip_year, :position)
      end
    end
  end
end
