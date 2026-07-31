class ApplicationController < ActionController::API
  class AuthorizationError < StandardError; end

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from AuthorizationError, with: :render_forbidden

  private

  def current_user
    @current_user
  end

  def authenticate!
    header = request.headers["Authorization"]
    token = header.to_s.split(" ").last
    payload = token && JsonWebToken.decode(token)
    @current_user = payload && User.find_by(id: payload[:user_id])
    render_unauthorized unless @current_user
  end

  def require_admin!
    authorize!(current_user&.super_admin? || current_user&.grade_admin?)
  end

  def require_super_admin!
    authorize!(current_user&.super_admin?)
  end

  def authorize!(condition)
    raise AuthorizationError unless condition
  end

  def render_unauthorized
    render json: { error: "unauthorized" }, status: :unauthorized
  end

  def render_forbidden
    render json: { error: "forbidden" }, status: :forbidden
  end

  def render_not_found(exception = nil)
    render json: { error: "not_found" }, status: :not_found
  end

  def render_unprocessable(exception)
    render json: { error: "unprocessable_entity", details: exception.record&.errors&.full_messages },
           status: :unprocessable_entity
  end

  def render_bad_request(exception)
    render json: { error: "bad_request", message: exception.message }, status: :bad_request
  end
end
