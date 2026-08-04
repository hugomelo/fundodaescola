module Api
  # Public endpoints (no JWT) for the forgot / reset password flow.
  class PasswordResetsController < ApplicationController
    # POST /api/auth/forgot_password  { email }
    # Always returns the same message to avoid leaking which emails exist.
    def create
      email = params[:email].to_s.strip.downcase
      user = User.find_by(email: email) if email.present?

      if user
        raw = user.generate_password_reset_token!
        UserMailer.with(user: user, token: raw).password_reset.deliver_later
      end

      render json: {
        message: "Se o e-mail estiver cadastrado, enviaremos instruções para redefinir a senha."
      }
    end

    # POST /api/auth/reset_password  { token, password, password_confirmation }
    def update
      user = User.find_by_password_reset_token(params[:token])
      unless user&.password_reset_period_valid?
        return render json: { error: "invalid_or_expired_token" }, status: :unprocessable_entity
      end

      password = params[:password].to_s
      confirmation = params[:password_confirmation].to_s
      if password.blank?
        return render json: { error: "password_required" }, status: :unprocessable_entity
      end
      if password != confirmation
        return render json: { error: "password_mismatch" }, status: :unprocessable_entity
      end

      user.password = password
      user.password_confirmation = confirmation
      if user.save
        user.clear_password_reset_token!
        render json: { message: "Senha atualizada. Você já pode entrar." }
      else
        render json: { error: "invalid_password", details: user.errors.full_messages },
               status: :unprocessable_entity
      end
    end
  end
end
