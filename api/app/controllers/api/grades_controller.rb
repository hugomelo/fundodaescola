module Api
  class GradesController < BaseController
    # GET /api/grades/:id/overview
    # Aggregate, non-identifying progress toward the grade goal.
    def overview
      grade = Grade.find(params[:id])
      authorize!(current_user.accessible_grade_ids.include?(grade.id))

      render json: {
        grade: {
          id: grade.id,
          name: grade.name,
          school_name: grade.school_name,
          currency: grade.currency
        },
        target_total_cents: grade.target_total_cents,
        net_raised_cents: grade.net_raised_cents,
        student_contributions_cents: grade.student_contributions_cents,
        event_cents: grade.event_cents,
        investment_cents: grade.investment_cents,
        progress_ratio: grade.progress_ratio.round(4),
        remaining_cents: [grade.target_total_cents - grade.net_raised_cents, 0].max,
        students_count: grade.students.active.count
      }
    end
  end
end
