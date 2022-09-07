# frozen_string_literal: true

class SessionsController < ApplicationController
  def create
    @user = User.find_by!(email: login_params[:email].downcase)
    unless @user.authenticate(login_params[:password])
      respond_with_error("Incorrect credentials, try again.", :unauthorized)
    else
      render
    end
  end

  private

    def login_params
      params.require(:login).permit(:email, :password)
    end
end
