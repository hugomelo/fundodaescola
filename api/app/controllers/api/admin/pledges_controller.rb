module Api
  module Admin
    class PledgesController < BaseController
      # GET /api/admin/students/:student_id/monthly_pledges
      def index
        student = find_student_in_scope!(params[:student_id])
        render json: { pledges: student.monthly_pledges.order(:month).map { |p| pledge_json(p) } }
      end

      # POST /api/admin/students/:student_id/monthly_pledges
      # Upsert by month (create or update).
      def create
        student = find_student_in_scope!(params[:student_id])
        pledge = student.monthly_pledges.find_or_initialize_by(month: month_param)
        pledge.assign_attributes(pledge_params)
        pledge.save!
        render json: { pledge: pledge_json(pledge) }, status: :created
      end

      # PATCH /api/admin/monthly_pledges/:id
      def update
        pledge = MonthlyPledge.find(params[:id])
        find_student_in_scope!(pledge.student_id)
        pledge.update!(pledge_params)
        render json: { pledge: pledge_json(pledge) }
      end

      # DELETE /api/admin/monthly_pledges/:id
      def destroy
        pledge = MonthlyPledge.find(params[:id])
        find_student_in_scope!(pledge.student_id)
        pledge.destroy!
        head :no_content
      end

      private

      def month_param
        Date.parse(params.require(:monthly_pledge)[:month].to_s).beginning_of_month
      end

      def pledge_json(pledge)
        { id: pledge.id, student_id: pledge.student_id, month: pledge.month,
          amount_cents: pledge.amount_cents, status: pledge.status }
      end

      def pledge_params
        params.require(:monthly_pledge).permit(:month, :amount_cents, :status)
      end
    end
  end
end
