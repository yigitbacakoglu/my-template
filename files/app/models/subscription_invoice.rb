class SubscriptionInvoice < ActiveRecord::Base
  attr_accessible :extra, :invoice_id, :provider, :subscription_id
  #serialize :extra
  belongs_to :subscription, :class_name => "::Subscription"
  after_create :send_mail

  def send_mail
    SubscriptionMailer.invoice_created(self).deliver
  end
end
