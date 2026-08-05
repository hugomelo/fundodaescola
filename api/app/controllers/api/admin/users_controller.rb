module Api
  module Admin
    class UsersController < BaseController
      # GET /api/admin/users
      def index
        render json: { users: scoped_users.order(:email).map { |u| user_json(u) } }
      end

      # GET /api/admin/users/:id
      def show
        render json: { user: user_json(find_user!) }
      end

      # POST /api/admin/users
      def create
        user = User.new(user_params)
        user.password = params.require(:user)[:password] if params.dig(:user, :password).present?
        authorize_role_assignment!(user)
        user.save!
        sync_students(user)
        render json: { user: user_json(user) }, status: :created
      end

      # PATCH /api/admin/users/:id
      def update
        user = find_user!
        user.assign_attributes(user_params)
        user.password = params.dig(:user, :password) if params.dig(:user, :password).present?
        authorize_role_assignment!(user)
        user.save!
        sync_students(user)
        render json: { user: user_json(user) }
      end

      # DELETE /api/admin/users/:id
      def destroy
        find_user!.destroy!
        head :no_content
      end

      # POST /api/admin/users/import
      # Multipart: file (CSV), grade_id, send_invite (optional boolean).
      # CSV columns: name, email, telefone?, aluno
      def import
        grade = find_import_grade!
        return if performed?

        content = import_content
        return render json: { error: "no_csv_provided" }, status: :bad_request if content.blank?

        result = UsersImporter.run(
          grade: grade,
          csv_content: content,
          send_invite: ActiveModel::Type::Boolean.new.cast(params[:send_invite])
        )
        render json: { result: result.to_h }
      end

      private

      def find_import_grade!
        grade_id = params[:grade_id].presence
        grade_id ||= current_user.grade_id if current_user.grade_admin?
        if grade_id.blank?
          render json: { error: "grade_required" }, status: :bad_request
          return nil
        end

        authorize_grade!(Grade.find(grade_id))
      end

      def import_content
        if params[:file].respond_to?(:read)
          params[:file].read
        else
          params[:csv]
        end
      end

      def scoped_users
        return User.all if current_user.super_admin?

        # Grade admins see parents linked to their grade's students.
        User.where(role: :parent)
            .joins(:students)
            .where(students: { grade_id: current_user.grade_id }).distinct
      end

      def find_user!
        user = User.find(params[:id])
        authorize!(current_user.super_admin? || manageable_by_grade_admin?(user))
        user
      end

      def manageable_by_grade_admin?(user)
        user.parent? && user.students.where(grade_id: current_user.grade_id).exists?
      end

      # A grade admin may only create/manage parents; super admin may set any role.
      def authorize_role_assignment!(user)
        return if current_user.super_admin?

        authorize!(user.parent?)
        user.grade_id = nil
      end

      def sync_students(user)
        ids = Array(params.dig(:user, :student_ids)).map(&:to_i).reject(&:zero?)
        return if params.dig(:user, :student_ids).nil?

        # Grade admins may only link students within their own grade.
        allowed = if current_user.super_admin?
                    Student.where(id: ids)
                  else
                    Student.where(id: ids, grade_id: current_user.grade_id)
                  end
        user.student_ids = allowed.pluck(:id)
      end

      def user_json(user)
        {
          id: user.id, email: user.email, name: user.name, phone: user.phone, role: user.role,
          grade_id: user.grade_id,
          student_ids: user.student_ids,
          students: user.students.map { |s| { id: s.id, display_name: s.display_name, grade_id: s.grade_id } }
        }
      end

      def user_params
        params.require(:user).permit(:email, :name, :phone, :role, :grade_id)
      end
    end
  end
end
