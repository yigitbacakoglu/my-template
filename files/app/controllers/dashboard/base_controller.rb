#encoding: utf-8
module Dashboard
  class BaseController < ApplicationController
    layout 'application'
    before_filter :authenticate_user!

    private


    def set_params
      params[:q] ||= {}
      params[:q][:s] ||= 'created_at desc'
    end

  end
end
