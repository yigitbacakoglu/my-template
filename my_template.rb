##
# Application Generator Template
# Usage: rails new APP_NAME  -T -m https://raw.github.com/yigitbacakoglu/my-template/master/my_template.rb
#
# If you are customizing this template, you can use any methods provided by Thor::Actions
# http://rubydoc.info/github/wycats/thor/master/Thor/Actions
# and Rails::Generators::Actions
# http://github.com/rails/rails/blob/master/railties/lib/rails/generators/actions.rb

@path = 'https://raw.github.com/yigitbacakoglu/my-template/master/files/'

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
gem 'paperclip'
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


####### OPTIONAL #########


if yes?('Would you like to use delayed job for background job? (yes/no)')
  puts "Adding delayed job ..."
  gem 'delayed_job_active_record'
  gem "daemons"
  gem 'dj_mon'
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

#Devise
generate 'devise:install'
generate 'devise:views'

gsub_file 'config/application.rb', /:password/, ':password, :password_confirmation'
generate 'devise user name:string'
gsub_file 'app/models/user.rb', /:remember_me/, ':remember_me, :name'

gsub_file 'config/initializers/devise.rb', /please-change-me-at-config-initializers-devise@example.com/, 'CHANGEME@example.com'

# Omniauth settings
if(added_social rescue false)
  
  line = "==> OmniAuth"
  gsub_file 'config/initializers/devise.rb', /(#{Regexp.escape(line)})/mi do |match|
    "#{match}\n  
    config.omniauth :facebook, 'CHANGEME', 'CHANGEMECHANGEME', :scope => 'email,publish_stream'\n
    config.omniauth :google_oauth2, 'CHANGEME.apps.googleusercontent.com', 'CHANGEMECHANGEME'\n
    config.omniauth :linkedin, 'CHANGEME', 'CHANGEMECHANGEME'\n
    config.omniauth :twitter, 'CHANGEME', 'CHANGEMECHANGEME'\n
    "
  end  
  
  gsub_file 'config/routes.rb', /  devise_for :users/ do <<-RUBY
    devise_for :users, :controllers => {:omniauth_callbacks => "users/omniauth_callbacks"}
  RUBY
  end
  
  inside 'app/controllers/users' do  
    get @path + 'app/controllers/users/omniauth_callbacks_controller.rb', 'app/controllers/users/omniauth_callbacks_controller.rb'
  end
  
end

# Client Side
generate 'client_side_validations:install'

# Twitter bootstrap
generate 'bootstrap:install --no-coffeescript'
generate 'bootstrap:layout application -f'


# Welcome and Dashboard
generate(:controller, 'home')
get @path + 'app/views/home/index.html.erb', 'app/views/home/index.html.erb'

inject_into_file 'app/controllers/home_controller.rb', :before => 'end' do <<-RUBY
  skip_before_filter :authenticate_user!, :only => :index
  def index
  end
RUBY
end

route "root :to => 'home#index'"

# Mail Settings

append_file 'config/environment.rb' do <<-RUBY
  #Mail Settings
  config.action_mailer.default_url_options = { :host => 'localhost:3000' }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
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

generate "rails g model Authentication uid:string provider:string oauth_token:string oauth_token_secret:string user_id:integer"

gsub_file 'app/models/authentication.rb', /ActiveRecord::Base/ do <<-RUBY
  attr_accessible :oauth_token, :oauth_token_secret, :provider, :uid, :user_id
  belongs_to :user
RUBY
end

gsub_file 'app/models/user.rb', /ActiveRecord::Base/ do <<-RUBY
  has_many :authentications
RUBY
end


rake 'db:migrate'

# Git
append_file '.gitignore' do <<-GIT
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

git :init
git :add => '.'
git :commit => '-m "close #1 Install Rails "'








