class AuthenticationsController < ApplicationController

  def destroy
    @authentication = current_user.authentications.find(params[:id])
    @authentication.destroy
    flash[:notice] = "Successfully destroyed authentication."
    redirect_to dashboard_account_path
  end
end