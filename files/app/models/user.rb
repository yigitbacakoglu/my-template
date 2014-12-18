class User < ActiveRecord::Base
  has_many :authentications

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :omniauthable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me
  # attr_accessible :title, :body

  def self.new_with_session(params, session)
    super.tap do |user|
      if session["devise.omniauth"]
        user.build_with_provider(session["devise.omniauth"])
      end
    end
  end

  def password_required?
    (authentications.empty? || !password.blank?) && (!persisted? || password.present? || password_confirmation.present?)
  end


  def build_with_provider(omniauth)
    user_info = omniauth['info']
    provider = omniauth['provider']
    self.username = user_info['nickname']
    #self.profile_image_url ||= omniauth['info']['image']
    self.authentications.build(
        :provider => provider,
        :oauth_token => omniauth['credentials']['token'],
        :oauth_token_secret => omniauth['credentials']['secret'],
        :uid => omniauth['uid'])
  end

end