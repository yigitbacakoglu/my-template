if Rails.env.production?
  #Stripe.api_key = "sk_live"
  #STRIPE_PUBLIC_KEY = "pk_live"


  Stripe.api_key = "sk_live"
  STRIPE_PUBLIC_KEY = "pk_live"

else
  Stripe.api_key = "sk_test"
  STRIPE_PUBLIC_KEY = "pk_test"
end
