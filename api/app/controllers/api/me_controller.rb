module Api
  class MeController < BaseController
    # GET /api/me
    def show
      render json: { user: UserSerializer.call(current_user) }
    end
  end
end
