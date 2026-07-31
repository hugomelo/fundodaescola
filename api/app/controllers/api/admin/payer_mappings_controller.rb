module Api
  module Admin
    class PayerMappingsController < BaseController
      # GET /api/admin/grades/:grade_id/payer_mappings
      def index
        grade = find_grade!
        render json: { payer_mappings: grade.payer_mappings.order(:payer_text).map { |m| mapping_json(m) } }
      end

      # POST /api/admin/grades/:grade_id/payer_mappings
      # Upsert by payer_text; optionally re-map matching payments.
      def create
        grade = find_grade!
        mapping = grade.payer_mappings.find_or_initialize_by(payer_text: params.require(:payer_mapping)[:payer_text].to_s.strip)
        mapping.assign_attributes(mapping_params)
        mapping.save!
        apply_to_existing(grade, mapping) if params[:apply_existing].present?
        render json: { payer_mapping: mapping_json(mapping) }, status: :created
      end

      # PATCH /api/admin/payer_mappings/:id
      def update
        mapping = find_mapping!
        mapping.update!(mapping_params)
        apply_to_existing(mapping.grade, mapping) if params[:apply_existing].present?
        render json: { payer_mapping: mapping_json(mapping) }
      end

      # DELETE /api/admin/payer_mappings/:id
      def destroy
        find_mapping!.destroy!
        head :no_content
      end

      private

      # Retroactively apply a mapping to already-imported payments with the same description.
      def apply_to_existing(grade, mapping)
        scope = grade.payments.where("LOWER(description) = ?", mapping.payer_text.downcase)
        if mapping.maps_to_event?
          scope.update_all(kind: Payment.kinds[:event], student_id: nil, payer_mapping_id: mapping.id)
        else
          scope.update_all(kind: Payment.kinds[:student_contribution], student_id: mapping.student_id, payer_mapping_id: mapping.id)
        end
      end

      def find_mapping!
        mapping = PayerMapping.find(params[:id])
        authorize!(current_user.can_admin_grade?(mapping.grade_id))
        mapping
      end

      def mapping_json(mapping)
        { id: mapping.id, grade_id: mapping.grade_id, payer_text: mapping.payer_text,
          student_id: mapping.student_id, maps_to_event: mapping.maps_to_event }
      end

      def mapping_params
        params.require(:payer_mapping).permit(:payer_text, :student_id, :maps_to_event)
      end
    end
  end
end
