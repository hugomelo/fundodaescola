module Api
  module Admin
    class StudentsController < BaseController
      # GET /api/admin/grades/:grade_id/students
      def index
        grade = find_grade!
        render json: { students: grade.students.order(:full_name).map { |s| student_json(s) } }
      end

      # POST /api/admin/grades/:grade_id/students
      def create
        grade = find_grade!
        student = grade.students.create!(student_params)
        render json: { student: student_json(student) }, status: :created
      end

      # GET /api/admin/students/:id
      def show
        render json: { student: student_json(find_student_in_scope!(params[:id]), detailed: true) }
      end

      # PATCH /api/admin/students/:id
      def update
        student = find_student_in_scope!(params[:id])
        student.update!(student_params)
        render json: { student: student_json(student, detailed: true) }
      end

      # DELETE /api/admin/students/:id
      def destroy
        find_student_in_scope!(params[:id]).destroy!
        head :no_content
      end

      private

      def student_json(student, detailed: false)
        contributed = student.contributed_cents
        expected = student.expected_cents
        base = {
          id: student.id,
          grade_id: student.grade_id,
          full_name: student.full_name,
          display_name: student.display_name,
          active: student.active,
          enrolled_from: student.enrolled_from,
          enrolled_until: student.enrolled_until,
          contributed_cents: contributed,
          expected_cents: expected,
          balance_cents: contributed - expected,
          latest_pledge_cents: student.effective_pledge(Date.current.beginning_of_month)&.first
        }
        return base unless detailed

        base.merge(
          pledges: student.monthly_pledges.order(:month).map { |p| pledge_json(p) }
        )
      end

      def pledge_json(pledge)
        { id: pledge.id, month: pledge.month, amount_cents: pledge.amount_cents, status: pledge.status }
      end

      def student_params
        params.require(:student).permit(:full_name, :display_name, :active, :enrolled_from, :enrolled_until)
      end
    end
  end
end
