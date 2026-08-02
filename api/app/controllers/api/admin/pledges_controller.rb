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
        pledge.assign_attributes(pledge_params.except(:month))
        pledge.save!
        render json: { pledge: pledge_json(pledge) }, status: :created
      end

      # PATCH /api/admin/monthly_pledges/:id
      def update
        pledge = MonthlyPledge.find(params[:id])
        find_student_in_scope!(pledge.student_id)
        attrs = pledge_params.except(:month)
        attrs[:month] = month_param if params.dig(:monthly_pledge, :month).present?
        pledge.update!(attrs)
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
        raw = params.require(:monthly_pledge)[:month].to_s.strip
        # Accept "YYYY-MM" (from <input type="month">) as well as full dates.
        raw = "#{raw}-01" if raw =~ /\A\d{4}-\d{2}\z/
        Date.parse(raw).beginning_of_month
      rescue Date::Error
        raise ActionController::BadRequest, "invalid month: #{raw}"
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
