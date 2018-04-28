class ClientsController < ApplicationController
  before_action :set_lister

  def show
    begin
      render json: @lister.clients.map(&:sanitize_attributes), status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def destroy
    begin
      @lister.clients.find(params[:client_id]).destroy!
      render json: @lister.clients.map(&:sanitize_attributes), status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def create

    begin
      if params[:user_id].present?
        user = User.find(params[:user_id])
      elsif User.find_by_email params[:email]
        user = User.find_by_email params[:email]
      else
        user = User.create! first_name: params[:first_name], last_name: params[:last_name], email: params[:email], phone_number: params[:phone_number], password_digest: SecureRandom.urlsafe_base64(nil, false)
        sql = "UPDATE `users` SET `password_digest` = '' WHERE `users`.`id` = #{user.id}"
        ActiveRecord::Base.connection.execute(sql)
      end

      @lister.clients << Client.create(
          user: user,
          note: params[:note],
          lister: @lister
      ) unless Client.where(user: user, lister: @lister).size > 0

      render json: @lister.clients.map(&:sanitize_attributes), status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  private

  def set_lister
    @lister = (request.original_url.include? 'stores') ? current_store_auth : current_user.hair_dresser
  end

end
