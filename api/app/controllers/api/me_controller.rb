module Api
  class MeController < BaseController
    # GET /api/me
    def show
      render json: { user: UserSerializer.call(current_user) }
    end

    # PATCH /api/me  { user: { name, phone, current_password, password, password_confirmation } }
    def update
      user = current_user
      attrs = profile_params

      if password_change_requested?
        unless user.authenticate(params.dig(:user, :current_password).to_s)
          return render json: { error: "invalid_current_password" }, status: :unprocessable_entity
        end

        password = params.dig(:user, :password).to_s
        confirmation = params.dig(:user, :password_confirmation).to_s
        if password != confirmation
          return render json: { error: "password_mismatch" }, status: :unprocessable_entity
        end

        user.password = password
        user.password_confirmation = confirmation
      end

      user.assign_attributes(attrs)
      if user.save
        render json: { user: UserSerializer.call(user) }
      else
        render json: { error: "invalid", details: user.errors.full_messages },
               status: :unprocessable_entity
      end
    end

    private

    def profile_params
      params.require(:user).permit(:name, :phone)
    end

    def password_change_requested?
      params.dig(:user, :password).present?
    end
  end
end
