module Api
  module Admin
    class InvestmentEntriesController < BaseController
      # GET /api/admin/grades/:grade_id/investment_entries
      def index
        grade = find_grade!
        render json: {
          investment_entries: grade.investment_entries.order(:month).map { |e| entry_json(e) },
          total_cents: grade.investment_cents
        }
      end

      # POST /api/admin/grades/:grade_id/investment_entries
      # Upsert by month.
      def create
        grade = find_grade!
        entry = grade.investment_entries.find_or_initialize_by(month: month_param)
        entry.assign_attributes(entry_params)
        entry.save!
        render json: { investment_entry: entry_json(entry) }, status: :created
      end

      # PATCH /api/admin/investment_entries/:id
      def update
        entry = find_entry!
        entry.update!(entry_params)
        render json: { investment_entry: entry_json(entry) }
      end

      # DELETE /api/admin/investment_entries/:id
      def destroy
        find_entry!.destroy!
        head :no_content
      end

      private

      def find_entry!
        entry = InvestmentEntry.find(params[:id])
        authorize!(current_user.can_admin_grade?(entry.grade_id))
        entry
      end

      def month_param
        Date.parse(params.require(:investment_entry)[:month].to_s).beginning_of_month
      end

      def entry_json(entry)
        { id: entry.id, grade_id: entry.grade_id, month: entry.month,
          amount_cents: entry.amount_cents, note: entry.note }
      end

      def entry_params
        params.require(:investment_entry).permit(:month, :amount_cents, :note)
      end
    end
  end
end
