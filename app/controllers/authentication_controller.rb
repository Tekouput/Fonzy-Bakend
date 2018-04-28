class AuthenticationController < ApplicationController
  skip_before_action :authenticate_request

  def authenticate
    begin
      command = AuthenticateUser.call(params[:email], params[:password])

      if command.success?

        user = command.user

        new_state = user.created_at == user.updated_at
        temp_cre = user.created_at
        temp_upd = user.updated_at

        user.last_ip = request.remote_ip
        user.geocode
        user.save!

        if new_state
          user.update! created_at: temp_cre, updated_at: temp_upd
        end

        render json: { auth_token: command.result, user: (User.sanitize_atributes user.id), new_user: user.created_at == user.updated_at}
      else
        render json: { error: command.errors }, status: :unauthorized
      end
    rescue => e
      render json: {error: e}
    end
  end

  def omniauth
    begin
      case params[:provider]
        when 'facebook'

          object = Facebook.get_object(extract_token, '/me?fields=id,name,picture,email')
          command = object.nil? ? {} : (auth_facebook object)

          user = command[:user]

          new_state = user.created_at == user.updated_at
          temp_cre = user.created_at

          user.last_ip = request.remote_ip
          user.geocode
          user.save!

          if new_state || command[:new_record?]
            user.update! created_at: temp_cre, updated_at: temp_cre
          end

          if command[:token]
            render json: { auth_token: command[:token], user: (User.sanitize_atributes user.id), new_user: new_state }, status: :ok
          else
            render json: { error: 'Invalid credentials' }, status: :unauthorized
          end

        when 'google'

          object = Google.get_object(extract_token)
          command = object.nil? ? {} : (auth_google object)

          user = command[:user]

          new_state = user.created_at == user.updated_at
          temp_cre = user.created_at
          temp_upd = user.updated_at

          user.last_ip = request.remote_ip
          user.geocode
          user.save!

          if new_state || command[:new_record?]
            user.update! created_at: temp_cre, updated_at: temp_upd
          end

          if command[:token]
            render json: { auth_token: command[:token], user: (User.sanitize_atributes user.id),  new_user: new_state }, status: :ok
          else
            render json: { error: 'Invalid credentials' }, status: :unauthorized
          end

        else
          Rails.logger.info "Provider #{params[:provider]}: Can't find service (doesn't exist)"
          render json: { error: "Provider #{params[:provider]}: Can't find service, doesn't exist"}, status: :not_found
      end
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  private

  def extract_token
    request.env['HTTP_AUTHORIZATION']
  end

  def auth_facebook(object)
    command = AuthenticateUserOauth.call(object['email']).result
    user = command[:user]

    user_pro = user.uuid.blank?

    # Update user information
    user.uuid = object['id']
    user.provider = 'facebook'
    user.first_name = object['name']
    user.profile_pic = object["picture"]["data"]["url"]
    user.email = object["email"]

    temp_cre = user.created_at
    temp_upd = user.updated_at

    # Set random password for user
    if command[:new_record?] || user.password_digest.blank?
      user.password = SecureRandom.urlsafe_base64(nil, false)
    end

    user.save!

    if user_pro
      user.update! created_at: temp_cre, updated_at: temp_upd
    end

    command
  end

  def auth_google(object)
    command = AuthenticateUserOauth.call(object['id'], params[:provider]).result
    user = command[:user]

    # Update user information
    user.uuid = object['id']
    user.provider = 'google'
    user.first_name = object['given_name']
    user.last_name = object['family_name']
    user.profile_pic = object["picture"]
    user.email = object["email"]

    # Set random password for user
    if command[:new_record?]
      user.password = SecureRandom.urlsafe_base64(nil, false)
    end

    user.save!
    command
  end

end