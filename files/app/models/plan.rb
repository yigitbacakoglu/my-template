class Plan < ActiveRecord::Base
  has_many :subscriptions
  attr_accessible :description, :name, :price, :period, :trial_period, :trial_period_count, :dont_create_remote
  attr_accessor :dont_create_remote
  # for stripe
  #test_card: 4242424242424242
  #exp_month: 4
  #exp_year: 2015
  #cvc: 314

  after_create :create_remote_plan
  after_update :update_plan
  #intervals = "month", "year", "week"
  def remote_plan_needed?
    return false if dont_create_remote
    if Rails.env.test? || Rails.env.development?
      !self.id.in?(1..3)
    else
      true
    end
  end

  def self.active
    where(:deleted_at => nil)
  end

  # monthly weekly yearly
  def period_for_paypal
    self.period.to_s.downcase == "day" ? "daily" : "#{self.period.to_s.downcase}ly".to_sym
  end

  def trial_period_for_paypal
    self.trial_period.to_s.downcase == "day" ? "daily" : "#{self.trial_period.to_s.downcase}ly".to_sym
  end

  def trial_frequency
    self.trial_period_days.to_f / 30.0
  end

  def create_remote_plan
    if remote_plan_needed?

      Stripe::Plan.create({
                              id: self.id,
                              name: self.name,
                              amount: self.price.to_i * 100,
                              interval: self.period.to_s.downcase,
                              interval_count: 1,
                              trial_period_days: self.trial_period_days || 0,
                              currency: "gbp"
                          }, Stripe.api_key)
    end
  end

  def destroy
    touch(:deleted_at)
  end

  def trial_period_days
    return 0 if !trial_period.present? || !self.trial_period_count.present?
    self.trial_period_count.to_i * case trial_period
                                     when "week"
                                       7
                                     when "month"
                                       30
                                     when "year"
                                       365
                                   end
  end

  def remote_plan
    @remote_plan ||= Stripe::Plan.retrieve(self.id.to_s)
  end

  def update_plan
    if remote_plan_needed?
      if self.price_changed?
        remote_plan.delete
        #Stripe does not allow updating price etc.
        create_remote_plan
      elsif self.name_changed?
        return false if self.name.blank? || self.name_was.blank?
        p = Stripe::Plan.retrieve(self.name_was)
        p.name = self.name
        p.save
      end
    end
  end


end