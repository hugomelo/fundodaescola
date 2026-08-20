module Api
  module Admin
    class StudentNotesController < BaseController
      # GET /api/admin/students/:student_id/notes
      def index
        student = find_student_in_scope!(params[:student_id])
        render json: { notes: student.notes.chronological.includes(:user).map { |n| note_json(n) } }
      end

      # POST /api/admin/students/:student_id/notes
      def create
        student = find_student_in_scope!(params[:student_id])
        note = student.notes.create!(note_params.merge(user: current_user))
        render json: { note: note_json(note) }, status: :created
      end

      # DELETE /api/admin/notes/:id
      def destroy
        note = StudentNote.find(params[:id])
        find_student_in_scope!(note.student_id)
        note.destroy!
        head :no_content
      end

      private

      def note_json(note)
        {
          id: note.id,
          student_id: note.student_id,
          body: note.body,
          occurred_on: note.occurred_on,
          created_at: note.created_at,
          author: note.user && { id: note.user.id, name: note.user.name, email: note.user.email }
        }
      end

      def note_params
        params.require(:note).permit(:body, :occurred_on)
      end
    end
  end
end
