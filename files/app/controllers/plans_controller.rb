class PlansController < BaseController
  def index
    @plans = Plan.active.order("price")
  end
end
