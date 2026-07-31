module Api
  class StudentsController < BaseController
    before_action :set_student

    # GET /api/students/:id/summary
    def summary
      render json: StudentSummary.call(@student)
    end

    # GET /api/students/:id/payments
    def payments
      records = @student.payments.where(kind: :student_contribution).order(paid_on: :desc, id: :desc)
      render json: { payments: records.map { |p| PaymentSerializer.call(p) } }
    end

    private

    def set_student
      @student = Student.find(params[:id])
      authorize!(current_user.can_access_student?(@student.id))
    end
  end
end
