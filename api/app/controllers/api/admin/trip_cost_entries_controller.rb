module Api
  module Admin
    class TripCostEntriesController < BaseController
      # POST /api/admin/trips/:trip_id/cost_entries
      # Upsert a real reported cost for a given year (overrides projection).
      def create
        trip = find_trip!(params[:trip_id])
        entry = trip.cost_entries.find_or_initialize_by(year: params.require(:cost_entry)[:year])
        entry.amount_cents = params.require(:cost_entry)[:amount_cents]
        entry.save!
        render json: { cost_entry: entry_json(entry) }, status: :created
      end

      # PATCH /api/admin/trip_cost_entries/:id
      def update
        entry = find_entry!
        entry.update!(entry_params)
        render json: { cost_entry: entry_json(entry) }
      end

      # DELETE /api/admin/trip_cost_entries/:id
      def destroy
        find_entry!.destroy!
        head :no_content
      end

      private

      def find_trip!(id)
        trip = Trip.find(id)
        authorize!(current_user.can_admin_grade?(trip.grade_id))
        trip
      end

      def find_entry!
        entry = TripCostEntry.find(params[:id])
        authorize!(current_user.can_admin_grade?(entry.trip.grade_id))
        entry
      end

      def entry_json(entry)
        { id: entry.id, trip_id: entry.trip_id, year: entry.year, amount_cents: entry.amount_cents }
      end

      def entry_params
        params.require(:cost_entry).permit(:year, :amount_cents)
      end
    end
  end
end
