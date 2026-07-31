module Api
  class SessionsController < ApplicationController
    # POST /api/auth/login
    def create
      user = User.find_by("LOWER(email) = ?", params[:email].to_s.strip.downcase)

      if user&.authenticate(params[:password])
        token = JsonWebToken.encode({ user_id: user.id })
        render json: { token: token, user: UserSerializer.call(user) }
      else
        render json: { error: "invalid_credentials" }, status: :unauthorized
      end
    end
  end
end
