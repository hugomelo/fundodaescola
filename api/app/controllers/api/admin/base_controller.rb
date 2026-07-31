module Api
  module Admin
    class BaseController < Api::BaseController
      before_action :require_admin!

      private

      # Ensure the current admin is allowed to act on the given grade.
      def authorize_grade!(grade)
        authorize!(current_user.can_admin_grade?(grade.id))
        grade
      end

      # Scope of grades this admin can manage.
      def admin_grades
        if current_user.super_admin?
          Grade.all
        else
          Grade.where(id: current_user.grade_id)
        end
      end

      def find_grade!
        authorize_grade!(Grade.find(params[:grade_id] || params[:id]))
      end

      def find_student_in_scope!(id)
        student = Student.find(id)
        authorize!(current_user.can_admin_grade?(student.grade_id))
        student
      end
    end
  end
end
