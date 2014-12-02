class SubscriptionMailer < ActionMailer::Base
  add_template_helper(ApplicationHelper)
  default from: "CHANGEME <noreply@CHANGEME.com>"
  default :bcc => "archive@CHANGEME.com"
  layout "mail"


  def invoice_created(subscription_invoice)
    @subscription = subscription_invoice.subscription
    @user = @subscription.user
    mail to: @user.email, subject: "Subscription Invoice Created"
  end

  def deactivated_to_customer(subscription)
    @subscription = subscription
    @user = subscription.user
    mail to: @user.email, subject: "Your subscription has been Deactivated!"
  end

  def deactivated_to_admin(subscription)
    @subscription = subscription
    @user = subscription.user
    mail to: "subscriptions@CHANGEME.com", subject: "Customer subscription has been Deactivated!"
  end

  def activated_to_admin(subscription)
    @subscription = subscription
    @user = subscription.user
    mail to: "subscriptions@CHANGEME.com", subject: "Customer subscription has been Activated!"
  end

  def activated_to_customer(subscription)
    @subscription = subscription
    @user = subscription.user
    mail to: @user.email, subject: "Your subscription has been Activated"
  end

  def trial_will_end(subscription)
    @subscription = subscription
    @user = subscription.user
    mail to: @user.email, subject: "Your subscription trial will end soon"
  end

end