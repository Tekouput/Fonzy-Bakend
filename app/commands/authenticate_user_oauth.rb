class AuthenticateUserOauth
  prepend SimpleCommand

  def initialize(email)
    @email = email
  end

  def call
    {
      token: (JsonWebToken.encode(user_id: user.id) if user),
      new_record?: (user.new_record? if user),
      user: (user if user)
    }
  end

  private

  attr_accessor :email

  def user
    user = User.where(email: email).first_or_create
    return user if user

    errors.add :user_authentication, 'couldn\'t connect'
    nil
  end
end