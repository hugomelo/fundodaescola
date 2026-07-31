module Api
  module Admin
    class EventsController < BaseController
      # GET /api/admin/grades/:grade_id/events
      def index
        grade = find_grade!
        render json: { events: grade.events.order(starts_on: :desc).map { |e| event_json(e) } }
      end

      # POST /api/admin/grades/:grade_id/events
      def create
        grade = find_grade!
        event = grade.events.create!(event_params)
        flagged = flag_payments_on(grade, event) if params[:flag_payments].present?
        render json: { event: event_json(event), flagged: flagged }, status: :created
      end

      # PATCH /api/admin/events/:id
      def update
        event = find_event!
        event.update!(event_params)
        render json: { event: event_json(event) }
      end

      # DELETE /api/admin/events/:id
      def destroy
        find_event!.destroy!
        head :no_content
      end

      private

      # Retroactively flag existing payments that fall on this event's dates.
      def flag_payments_on(grade, event)
        range = event.ends_on ? (event.starts_on..event.ends_on) : (event.starts_on..event.starts_on)
        grade.payments.where(paid_on: range).update_all(needs_review: true)
      end

      def find_event!
        event = Event.find(params[:id])
        authorize!(current_user.can_admin_grade?(event.grade_id))
        event
      end

      def event_json(event)
        { id: event.id, grade_id: event.grade_id, name: event.name,
          starts_on: event.starts_on, ends_on: event.ends_on }
      end

      def event_params
        params.require(:event).permit(:name, :starts_on, :ends_on)
      end
    end
  end
end
