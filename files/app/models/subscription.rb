class Subscription < ActiveRecord::Base
  include Stripe::Callbacks

  attr_accessible :plan_id, :user_id, :stripe_card_token, :paypal_customer_token,
                  :paypal_payment_token
  belongs_to :plan
  belongs_to :user
  has_many :invoices, :class_name => "SubscriptionInvoice"

  validates_presence_of :plan_id
  validates_presence_of :user_id
  after_create :unsubscribe_user_from_previous
  before_create :set_amount

  scope :active, -> { where(state: 'active') }

  state_machine :state, :initial => :active do

    #Admin cancels subscription which requires to subscribe new plan.
    event :cancel do
      transition :to => :canceled
    end
    #PayPal or Stripe deactivates subscription if payment cannot be charged e.g. insufficient funds
    event :deactivate do
      transition :from => :canceled, :to => :deactivated
      transition :from => :active, :to => :deactivated
      transition :from => :deactivated, :to => :deactivated
    end
    #Can be re-activated from deactive
    event :activate do
      transition :from => :canceled, :to => :active
      transition :from => :deactivated, :to => :active
      #transition :from => :active, :to => :active
    end

    before_transition :to => :active do |subscription|
      begin
        subscription.update_with_payment
      rescue Exception => e
        subscription.errors.add(:base, e.message)
        false
      end
    end

    after_transition :on => :cancel, :do => :unsubscribe
    #after_transition :on => :activate, :do => :update_with_payment
    after_transition :to => :deactivated, :do => :send_deactivated_mail
  end

  # it gets next possible authorized events of current state
  def next_state_events
    t = self.state_transitions(:from => self.state.to_sym)
    authorized_events = Array.new
    t.each do |transition|
      authorized_events << transition
    end
    authorized_events
  end


  attr_accessor :stripe_card_token, :paypal_payment_token

  def save_with_payment
    result = false
    if valid?
      if paypal_payment_token.present?
        result = save_with_paypal_payment
      elsif paypal?
        #BillOutstandingAmount
        paypal.bill_outstanding
      else
        result = save_with_stripe_payment
      end
    end
    self.delay.send_activated_mail if result
    result
  end

  def update_with_payment
    result = false
    if valid?
      if paypal?
        #BillOutstandingAmount
        paypal.bill_outstanding
      else
        result = pay_last_invoices
      end
    end
    self.delay.send_activated_mail if result
    unless result
      raise "Payment failed"
    end
    result
  end


  def pay_last_invoices
    self.invoices.where(paid: false).each do |i|
      invoice = Stripe::Invoice.retrieve(i.invoice_id)
      invoice.pay
    end
    true
  end

  def paypal
    PaypalPayment.new(self)
  end


  def payment_provider
    paypal? ? "paypal" : "stripe"
  end

  def card_supported?
    stripe?
  end

  def paypal?
    paypal_customer_token.present?
  end

  def stripe?
    stripe_customer_token.present?
  end

  def save_with_paypal_payment
    response = paypal.make_recurring
    self.paypal_recurring_profile_token = response.profile_id
    save!
  end

  def email
    self[:email] || self.user.email
  end

  def save_with_stripe_payment
    customer = Stripe::Customer.create(description: email, plan: plan_id, card: stripe_card_token)
    self.stripe_customer_token = customer.id
    save!
  rescue Stripe::InvalidRequestError => e
    logger.error "Stripe error while creating customer: #{e.message}"
    errors.add :base, "There was a problem with your credit card."
    false
  end

  def payment_provided?
    stripe? || paypal?
  end


  def account_number
    if stripe_customer_token
      stripe_customer_token.sub('cus_', '')
    else
      ''
    end
  end

  def card_info
    return @card_info if @card_info.present?
    if self.stripe_customer_token
      subscription = Stripe::Customer.retrieve(stripe_customer_token)
      card = subscription.default_card
      if card
        card_info = subscription.cards.retrieve(card)

        @card_info = {last_four: card_info.last4, card_type: card_info.type, exp_month: card_info.exp_month, exp_year: card_info.exp_year}
      else
        {}
      end
    else
      {}
    end
  end

  def remove_card
    customer = Stripe::Customer.retrieve(stripe_customer_token)
    customer.cards.each do |card|
      card.delete()
    end
    @card_info = nil
  end

  def add_card token
    customer = Stripe::Customer.retrieve(stripe_customer_token)
    customer.cards.create(:card => token[:stripe_card_token])

    begin
      update_with_payment
    rescue
      errors.add(:base, "Payment Failed")
      false
    end
  end


  def active_on_stripe?
    customer = Stripe::Customer.retrieve(stripe_customer_token)
    subscription = customer.subscriptions.select { |sub| sub.plan.id == self.plan_id.to_s }.first
    if subscription.blank? || subscription.status == 'unpaid' || subscription.status == 'canceled'
      return false
    else
      return true
    end
  end

  def update_expiration
    update_attributes({
                          :expires_at => self.period_end
                      })
  end

  def period_end
    customer = Stripe::Customer.retrieve(stripe_customer_token)
    subscription = customer.subscriptions.select { |sub| sub.plan.id == self.plan_id.to_s }.first
    Time.at(subscription.current_period_end).strftime("%b %d, %Y")
  end


  def create_stripe_subscription
    Stripe::Customer.create(
        plan: plan_id,
        card: stripe_card_token,
        description: "#{plan.name} for #{user.full_name}"
    )
  rescue Stripe::InvalidRequestError => e
    logger.error("Stripe error while creating subscription: #{e.message}")
  end


  def unsubscribe
    self.send("unsubscribe_from_#{self.payment_provider}")
    true
  end

  def unsubscribe_from_paypal
    suspend_at_paypal
  end

  def unsubscribe_from_stripe
    customer = Stripe::Customer.retrieve(stripe_customer_token)
    subscription = customer.subscriptions.select { |sub| sub.plan.id == self.plan_id.to_s }.first
    unless subscription.nil?
      customer.subscriptions.retrieve(subscription[:id]).delete()
    end
  end

  def paypal_profile
    @ppr ||= PayPal::Recurring.new(:profile_id => paypal_recurring_profile_token)
  end

  def suspend_at_paypal
    paypal_profile.suspend
  end

  def reactivate_at_paypal
    paypal_profile.reactivate
  end

  def cancel_at_paypal
    paypal_profile.cancel
  end

  def admin_user?
    User.current && User.current.admin?
  end

  #Send mail on deactivating subscription
  def send_deactivated_mail
    self.delay.send_deactivated_mail_to_customer
    self.delay.send_deactivated_mail_to_admin
  end

  #handle_asynchronously :send_deactivated_mail

  def send_activated_mail
    SubscriptionMailer.activated_to_customer(self).deliver
    SubscriptionMailer.activated_to_admin(self).deliver
  end

  #handle_asynchronously :send_activated_mail


  def send_deactivated_mail_to_customer
    SubscriptionMailer.deactivated_to_customer(self).deliver
  end

  def send_deactivated_mail_to_admin
    SubscriptionMailer.deactivated_to_admin(self).deliver
  end

  def set_invoice(invoice)
    _invoice = self.invoices.find_or_create_by_invoice_id_and_provider(invoice.id, "stripe")
    _invoice.extra = invoice
    _invoice.paid = invoice.paid
    _invoice.closed = invoice.closed
    _invoice.save!
  end


#  Stripe Events - - - - - - - - - - - - - - - - - - - - -

#If invoice fails, deactivate subscription
  after_invoice_created! do |invoice, event|
    subscription = self.find_by_stripe_customer_token(invoice.customer)
    subscription.set_invoice(invoice)
  end

#If invoice fails, deactivate subscription
  after_invoice_payment_failed! do |invoice, event|
    subscription = self.find_by_stripe_customer_token(invoice.customer)
    subscription.set_invoice(invoice)
    subscription.deactivate! unless subscription.deactivated?
  end

  #If invoice fails, deactivate subscription
  after_invoice_payment_succeeded! do |invoice, event|
    subscription = self.find_by_stripe_customer_token(invoice.customer)
    subscription.set_invoice(invoice)
    subscription.activate! unless subscription.active?
  end
  #If invoice fails, deactivate subscription
  after_customer_subscription_trial_will_end! do |invoice, event|
    subscription = self.find_by_stripe_customer_token(invoice.customer)
    SubscriptionMailer.delay.trial_will_end(subscription)
  end

#  Stripe Events - - - - - - - - - - - - - - - - - - - - -

  def unsubscribe_user_from_previous
    self.user.subscriptions.each do |subscription|
      next if subscription.canceled? || (subscription == self)
      subscription.cancel!
    end
  end

  def set_amount
    self.paid_amount = self.plan.price
  end

end