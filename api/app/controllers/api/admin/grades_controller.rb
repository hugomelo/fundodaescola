module Api
  module Admin
    class GradesController < BaseController
      def index
        render json: { grades: admin_grades.order(:name).map { |g| grade_json(g) } }
      end

      def show
        grade = find_grade!
        render json: { grade: grade_json(grade, detailed: true) }
      end

      def create
        authorize!(current_user.super_admin?)
        grade = Grade.create!(grade_params)
        render json: { grade: grade_json(grade) }, status: :created
      end

      def update
        grade = find_grade!
        grade.update!(grade_params)
        render json: { grade: grade_json(grade, detailed: true) }
      end

      def destroy
        authorize!(current_user.super_admin?)
        Grade.find(params[:id]).destroy!
        head :no_content
      end

      # GET /api/admin/grades/:id/dashboard
      # Full per-student balances (admin-only) + grade totals.
      def dashboard
        grade = find_grade!
        up_to = Date.current.beginning_of_month
        students = grade.students.order(:full_name).map do |s|
          {
            id: s.id,
            full_name: s.full_name,
            display_name: s.display_name,
            active: s.active,
            enrolled_from: s.enrolled_from,
            enrolled_until: s.enrolled_until,
            contributed_cents: s.contributed_cents,
            expected_cents: s.expected_cents(up_to: up_to),
            balance_cents: s.balance_cents(up_to: up_to)
          }
        end

        render json: {
          grade: grade_json(grade, detailed: true),
          students: students
        }
      end

      private

      def grade_json(grade, detailed: false)
        base = {
          id: grade.id,
          name: grade.name,
          school_name: grade.school_name,
          currency: grade.currency,
          target_total_cents: grade.target_total_cents,
          school_year_start: grade.school_year_start,
          school_year_end: grade.school_year_end
        }
        return base unless detailed

        base.merge(
          description: grade.description,
          net_raised_cents: grade.net_raised_cents,
          student_contributions_cents: grade.student_contributions_cents,
          event_cents: grade.event_cents,
          investment_cents: grade.investment_cents,
          progress_ratio: grade.progress_ratio.round(4),
          students_count: grade.students.count
        )
      end

      def grade_params
        params.require(:grade).permit(
          :name, :school_name, :currency, :target_total_cents,
          :school_year_start, :school_year_end, :description
        )
      end
    end
  end
end
