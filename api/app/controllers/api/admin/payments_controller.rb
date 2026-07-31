module Api
  module Admin
    class PaymentsController < BaseController
      # GET /api/admin/grades/:grade_id/payments
      # Filters: ?kind=event|student_contribution  ?unmapped=1  ?review=1  ?student_id=  ?q=
      def index
        grade = find_grade!
        scope = grade.payments.order(paid_on: :desc, id: :desc)
        scope = scope.where(kind: params[:kind]) if params[:kind].present?
        scope = scope.where(student_id: params[:student_id]) if params[:student_id].present?
        scope = scope.where(student_id: nil, kind: :student_contribution) if params[:unmapped].present?
        scope = scope.where(needs_review: true) if params[:review].present?
        scope = scope.where("description ILIKE ?", "%#{params[:q]}%") if params[:q].present?

        limit = [params.fetch(:limit, 100).to_i, 500].min
        render json: {
          payments: scope.limit(limit).map { |p| PaymentSerializer.call(p) },
          total: scope.count,
          review_count: grade.payments.where(needs_review: true).count
        }
      end

      # POST /api/admin/grades/:grade_id/payments
      def create
        grade = find_grade!
        payment = grade.payments.new(payment_params)
        payment.save!
        render json: { payment: PaymentSerializer.call(payment) }, status: :created
      end

      # POST /api/admin/grades/:grade_id/payments/import
      # Accepts a multipart `file` or a raw `csv` string.
      def import
        grade = find_grade!
        content = import_content
        return render json: { error: "no_csv_provided" }, status: :bad_request if content.blank?

        result = BankStatementImporter.run(grade: grade, csv_content: content)
        render json: { result: result.to_h }
      end

      # PATCH /api/admin/payments/:id
      def update
        payment = find_payment!
        payment.assign_attributes(payment_params)
        # Any manual edit counts as a review unless the caller says otherwise.
        payment.needs_review = false unless params[:payment].key?(:needs_review)
        payment.save!
        render json: { payment: PaymentSerializer.call(payment) }
      end

      # DELETE /api/admin/payments/:id
      def destroy
        find_payment!.destroy!
        head :no_content
      end

      private

      def find_payment!
        payment = Payment.find(params[:id])
        authorize!(current_user.can_admin_grade?(payment.grade_id))
        payment
      end

      def import_content
        if params[:file].respond_to?(:read)
          params[:file].read
        else
          params[:csv]
        end
      end

      def payment_params
        params.require(:payment).permit(
          :paid_on, :paid_time, :description, :amount_cents, :kind, :student_id, :payer_mapping_id, :needs_review
        )
      end
    end
  end
end
