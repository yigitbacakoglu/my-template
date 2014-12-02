class SubscriptionsController < BaseController

  before_filter :set_subscription, only: [:remove_card, :add_card, :show, :fire]


  def new
    plan = Plan.active.find(params[:plan_id])
    @subscription = plan.subscriptions.build
    if params[:PayerID]
      @subscription.paypal_customer_token = params[:PayerID]
      @subscription.paypal_payment_token = params[:token]
      @subscription.email = @subscription.paypal.checkout_details.email
      @subscription.user = @current_user
      @subscription.token = params[:identifier_token] || SecureRandom.hex
      if @subscription.save_with_payment
        redirect_to @subscription, :notice => "Thank you for subscribing!" and return
      else
        render :new and return
      end
    end
  end

  def create
    @subscription = Subscription.new(params[:subscription])
    @subscription.user = @current_user
    @subscription.token = params[:identifier_token]
    if @subscription.save_with_payment
      redirect_to @subscription, :notice => "Thank you for subscribing!"
    else
      render :new
    end
  end

  def show
  end

  def remove_card
    @subscription.remove_card
    redirect_to @subscription
  end

  def add_card
    if @subscription.add_card(params[:subscription])
      redirect_to @subscription
    else
      render 'show'
    end
  end

  def fire
    if @subscription.send(params[:e].to_sym)
      flash[:success] = "Subscription is successfully updated"
      redirect_to subscription_path("my")
    else
      render 'show'
    end

  end

  def paypal_checkout
    plan = Plan.active.find(params[:plan_id])
    subscription = plan.subscriptions.build
    token = SecureRandom.hex
    redirect_to subscription.paypal.checkout_url(
                    return_url: new_subscription_url(:plan_id => plan.id, :identifier_token => token, host: Setting["site_host"]),
                    cancel_url: new_subscription_url(:plan_id => plan.id, :identifier_token => token, host: Setting["site_host"]),
                    ipn_url: paypal_ipn_url(:identifier_token => token, host: Setting["site_host"]),
                )
  end

  def set_subscription
    @subscription = current_user.subscriptions.last
    redirect_to plans_path and return if @subscription.blank? || @subscription.canceled?
  end

end
