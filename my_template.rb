##
# Application Generator Template
# Usage: rails new APP_NAME  -T -m https://raw.github.com/yigitbacakoglu/my-template/master/my_template.rb
#
# If you are customizing this template, you can use any methods provided by Thor::Actions
# http://rubydoc.info/github/wycats/thor/master/Thor/Actions
# and Rails::Generators::Actions
# http://github.com/rails/rails/blob/master/railties/lib/rails/generators/actions.rb

@path = 'https://raw.github.com/yigitbacakoglu/my-template/master/files/'
stripe = true
##### RECEIPES #####

gem 'devise', "3.2.2"
gem 'capistrano'
gem 'rvm-capistrano'
gem_group :development do
  gem 'capistrano-local-precompile', require: false
end
gem "client_side_validations"
gem "rails-settings-cached", "0.2.4"
gem 'state_machine'
gem "paperclip", "3.4.2"
gem "ransack" # Last officially released gem (Rails 3 and 4)
gem 'kaminari'
gem "nested_form"
gem 'newrelic_rpm'
gem 'airbrake'
gem_group :development do
  gem 'sqlite3'
end
gem_group :production do
  gem 'mysql2', "0.3.13"
  gem 'unicorn'
end
gem_group :assets do
  gem "therubyracer"
  gem "less-rails" #Sprockets (what Rails 3.1 uses for its asset pipeline) supports LESS
  gem "twitter-bootstrap-rails"
end
gem 'rails_admin'
gem 'haml', '>= 3.1.alpha.214'


####### OPTIONAL #########


if yes?('Would you like to use delayed job for background job? (yes/no)')
  puts "Adding delayed job ..."
  gem 'delayed_job_active_record'
  gem "daemons"
  gem 'dj_mon'
  dj_added = true
end


if yes?('Would you like to use stripe billing? (yes/no)')
  gem 'stripe'
  gem 'stripe-rails'
  say('Add this code where you will use stripe modal.  <%= javascript_include_tag "//js.stripe.com/v1/", "stripe/subscriptions" %>')
end


if yes?('Would you like to use social login (facebook, twitter, google+, linkedin) ? (yes/no)')
  added_social = true
  gem 'omniauth'
  gem 'omniauth-facebook'
  gem 'omniauth-twitter'
  gem 'omniauth-google-oauth2'
  gem 'omniauth-linkedin-oauth2'
end


# Bundle
run 'bundle install'
rake 'db:drop'
rake 'db:create'
rake 'db:migrate'

#Rails admin
generate "rails_admin:install"

#Devise
generate 'devise:install'
generate 'devise:views'

gsub_file 'config/application.rb', /:password/, ':password, :password_confirmation'
generate 'devise user name:string'
gsub_file 'app/models/user.rb', /:remember_me/, ':remember_me, :name'

gsub_file 'config/initializers/devise.rb', /please-change-me-at-config-initializers-devise@example.com/, 'CHANGEME@example.com'

# Omniauth settings
if (added_social rescue false)

  line = "==> OmniAuth"
  gsub_file 'config/initializers/devise.rb', /(#{Regexp.escape(line)})/mi do |match|
    "#{match}\n  
    config.omniauth :facebook, 'CHANGEME', 'CHANGEMECHANGEME', :scope => 'email,publish_stream'\n
    config.omniauth :google_oauth2, 'CHANGEME.apps.googleusercontent.com', 'CHANGEMECHANGEME'\n
    config.omniauth :linkedin, 'CHANGEME', 'CHANGEMECHANGEME'\n
    config.omniauth :twitter, 'CHANGEME', 'CHANGEMECHANGEME'\n
    "
  end

  gsub_file 'config/routes.rb', /  devise_for :users/ do
    <<-RUBY
    devise_for :users, :controllers => {:omniauth_callbacks => "users/omniauth_callbacks"}
    RUBY
  end

  inside 'app/controllers/users' do
    get @path + 'app/controllers/users/omniauth_callbacks_controller.rb', 'omniauth_callbacks_controller.rb'
  end

end

# Client Side
generate 'client_side_validations:install'

# Twitter bootstrap
generate 'bootstrap:install --no-coffeescript'
#generate 'bootstrap:layout application -f'


# Welcome and Dashboard
generate(:controller, 'home')
get @path + 'app/views/home/index.html.erb', 'app/views/home/index.html.erb'

inject_into_file 'app/controllers/home_controller.rb', :before => 'end' do
  <<-RUBY
  skip_before_filter :authenticate_user!, :only => :index
  def index
  end
  RUBY
end

inject_into_file 'app/controllers/application_controller.rb', :before => 'end' do
  <<-RUBY
  before_filter :set_current_user
  
  def set_current_user
    @current_user = current_user
    User.current = @current_user
  end
  
  def render_default_modal_form(title = nil, target = nil, options = {})
    @title = title
    target ||= \"\#{params[:controller]}/\#{params[:action]}\"
    render :partial => '/shared/default_modal_form', :locals => {:target => target, :options => options}
  end
  RUBY
end

route "root :to => 'home#index'"
route "get '/dashboard' => 'dashboard/overview#index', :as => :dashboard"

generate :model, "asset attachment:attachment user_id:integer type:string viewable_id:integer viewable_type:string"

inject_into_file 'app/models/asset.rb', :before => 'end' do
  <<-RUBY
    \n belongs_to :user     \n
    belongs_to :viewable, :polymorphic => true \n
                            \n
    def self.not_deleted   \n
      where(:deleted_at => nil)  \n
    end              \n
  RUBY
end


get @path + 'app/models/avatar.rb', 'app/models/avatar.rb'

# Mail Settings

append_file 'config/environment.rb' do
  <<-RUBY
  #Mail Settings
  ActionMailer::Base.default_url_options = { :host => 'localhost:3000' }
  ActionMailer::Base.delivery_method = :smtp
  ActionMailer::Base.smtp_settings = {
      :address              => "smtp.gmail.com",
      :port                 => 587,
      :domain               => 'gmail.com',
      :user_name            => 'rubyonrailsrailsmailtest@gmail.com',
      :password             => 'secret',
      :authentication       => 'plain',
      :enable_starttls_auto => true
  }
  RUBY
end

generate :model, "Authentication uid:string provider:string oauth_token:string oauth_token_secret:string user_id:integer"
line = "ActiveRecord::Base"

gsub_file 'app/models/authentication.rb', /(#{Regexp.escape(line)})/mi do |match|
  "#{match}\n
    belongs_to :user"
end

gsub_file 'app/models/user.rb', /(#{Regexp.escape(line)})/mi do |match|
  "#{match}\n
     has_many :authentications\n
     has_many :subscriptions
     \n
     def self.current
       Thread.current[:user]
     end
    \n
     def self.current=(user)
       Thread.current[:user] = user
     end
     "
end

gsub_file 'app/models/user.rb', /:registerable/, ":registerable, :omniauthable"

get @path + 'app/controllers/authentications_controller.rb', 'app/controllers/authentications_controller.rb'
route "resources :authentications, :only => :destroy"


get @path + 'app/controllers/dashboard/base_controller.rb', 'app/controllers/dashboard/base_controller.rb'
get @path + 'app/controllers/base_controller.rb', 'app/controllers/base_controller.rb'
get @path + 'app/controllers/dashboard/overview_controller.rb', 'app/controllers/dashboard/overview_controller.rb'
get @path + 'app/views/dashboard/overview/index.html.erb', 'app/views/dashboard/overview/index.html.erb'


get @path + 'app/views/shared/_default_modal_form.js.erb', 'app/views/shared/_default_modal_form.js.erb'
get @path + 'app/views/shared/_errors.js.erb', 'app/views/shared/_errors.js.erb'
get @path + 'app/views/shared/_errors.html.erb', 'app/views/shared/_errors.html.erb'
get @path + 'app/views/shared/_flashes.js.erb', 'app/views/shared/_flashes.js.erb'
get @path + 'app/views/shared/_interactive_address_fields.html.erb', 'app/views/shared/_interactive_address_fields.html.erb'
get @path + 'app/views/layouts/_default_modal.html.erb', 'app/views/layouts/_default_modal.html.erb'
get @path + 'app/views/layouts/_navbar.html.erb', 'app/views/layouts/_navbar.html.erb'


get @path + 'app/assets/images/default-avatar.gif', 'app/assets/images/default-avatar.gif'
get @path + 'app/assets/images/missing.png', 'app/assets/images/missing.png'


if (stripe rescue false)

  generate :model, "subscription plan_id:integer user_id:integer starts_at:datetime ends_at:datetime paid_amount:decimal state:string email:string stripe_subscription_id:string stripe_customer_token:string paypal_customer_token:string paypal_recurring_profile_token:string token:string deleted_at:datetime "
  generate :model, "subscription_invoice invoice_id:string subscription_id:integer provider:string extra:text paid:boolean closed:boolean"
  generate :model, "plan name:string description:text price:decimal period:string trial_period:string trial_period_count:string deleted_at:datetime"

  remove_file 'app/models/plan.rb'
  remove_file 'app/models/subscription.rb'
  remove_file 'app/models/subscription_invoice.rb'

  get @path + 'app/models/plan.rb', 'app/models/plan.rb'
  get @path + 'app/models/subscription.rb', 'app/models/subscription.rb'
  get @path + 'app/models/subscription_invoice.rb', 'app/models/subscription_invoice.rb'


  get @path + 'app/views/plans/index.html.erb', 'app/views/plans/index.html.erb'
  get @path + 'app/views/subscriptions/_new_credit_card.html.erb', 'app/views/subscriptions/_new_credit_card.html.erb'
  get @path + 'app/views/subscriptions/new.html.erb', 'app/views/subscriptions/new.html.erb'
  get @path + 'app/views/subscriptions/show.html.erb', 'app/views/subscriptions/show.html.erb'


  get @path + 'app/views/subscription_mailer/_detail_table.html.erb', 'app/views/subscription_mailer/_detail_table.html.erb'
  get @path + 'app/views/subscription_mailer/activated_to_admin.html.erb', 'app/views/subscription_mailer/activated_to_admin.html.erb'
  get @path + 'app/views/subscription_mailer/activated_to_customer.html.erb', 'app/views/subscription_mailer/activated_to_customer.html.erb'
  get @path + 'app/views/subscription_mailer/deactivated_to_admin.html.erb', 'app/views/subscription_mailer/deactivated_to_admin.html.erb'
  get @path + 'app/views/subscription_mailer/deactivated_to_customer.html.erb', 'app/views/subscription_mailer/deactivated_to_customer.html.erb'
  get @path + 'app/views/subscription_mailer/invoice_created.html.erb', 'app/views/subscription_mailer/invoice_created.html.erb'
  get @path + 'app/views/subscription_mailer/trial_will_end.html.erb', 'app/views/subscription_mailer/trial_will_end.html.erb'

  get @path + 'app/helpers/base_helper.rb', 'app/helpers/base_helper.rb'


  get @path + 'app/mailers/subscription_mailer.rb', 'app/mailers/subscription_mailer.rb'
  get @path + 'app/controllers/subscriptions_controller.rb', 'app/controllers/subscriptions_controller.rb'
  get @path + 'app/controllers/plans_controller.rb', 'app/controllers/plans_controller.rb'

  route "resources :subscriptions do
    member do
      delete :remove_card
      get :add_card
      post :add_card
      put :fire
    end
  end
  resources :plans
"

  get @path + 'app/assets/javascripts/stripe/subscriptions.js.coffee', 'appapp/assets/javascripts/stripe/subscriptions.js.coffee'
  get @path + 'config/initializers/stripe.rb', 'config/initializers/stripe.rb'


end

if (dj_added rescue false)
  inject_into_file 'config/routes.rb', :after => 'Application.routes.draw do' do
    <<-RUBY
      mount DjMon::Engine => 'dj_mon'
    RUBY
  end

  get @path + 'config/initializers/dj_mon.rb', 'config/initializers/dj_mon.rb'

  generate "delayed_job:active_record"
end


inject_into_file 'app/assets/javascripts/application.js', :before => '//= require jquery_nested_form' do
  <<-RUBY
      //= require jquery_nested_form
  RUBY
end


#inject_into_file 'config/environments/production.rb', :before => 'end' do
#  <<-RUBY
#  config.assets.initialize_on_precompile = false
#  config.assets.precompile += ['vendor/assets/**/*']
#  config.assets.precompile = []
#  config.assets.precompile << Proc.new { |path|
#    begin
#      if !(path =~ /\.(html)\z/) #compile all non-html files
#        full_path = Rails.application.assets.resolve(path).to_path
#        app_assets_path = Rails.root.join('app', 'assets').to_path
#        vendor_assets_path = Rails.root.join('vendor', 'assets').to_path
#        lib_assets_path = Rails.root.join('lib', 'assets').to_path
#
#        if !config.assets.precompile.include?(full_path) && (!path.starts_with? '_')
#          puts "\t" + full_path.slice(Rails.root.to_path.size..-1)
#          true
#        else
#          false
#        end
#      else
#        false
#      end
#    rescue
#      next
#    end
#  }
#
#
#
#  RUBY
#end


remove_file "app/views/layouts/application.html.erb"
get @path + 'app/views/layouts/application.html.erb', 'app/views/layouts/application.html.erb'

remove_file "app/views/layouts/application.html.erb"
get @path + 'app/views/layouts/application.html.erb', 'app/views/layouts/application.html.erb'


remove_file "config/initializers/client_side_validations.rb"
get @path + 'config/initializers/client_side_validations.rb', 'config/initializers/client_side_validations.rb'


rake 'db:migrate'

# Git
append_file '.gitignore' do
  <<-GIT
/public/system
/public/uploads
/coverage
rerun.txt
.rspec
capybara-*.html
.DS_Store
.rbenv-vars
.rbenv-version
.bundle
db/*.sqlite3
db/database.yml
log/*.log
log/*.pid
.sass-cache/
tmp/**/*
.rvmrc
.DS_Store
db-dumps
**/.DS_Store
nbproject/**/*
.yardoc/**/*
.yardoc
nbproject
.idea
.idea/**/*
  GIT
end
remove_file "public/index.html"
git :init
git :add => '.'
git :commit => '-m "close #1 Install Rails "'








