module Api
  class BaseController < ApplicationController
    before_action :authenticate!
  end
end
