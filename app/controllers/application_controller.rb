require 'uri'
require 'net/http'
require "addressable/uri"

class ApplicationController < ActionController::API
  before_action :authenticate_request
  attr_reader :current_user
  skip_before_action :authenticate_request, only: [:instagram_pictures, :query_user, :get_address, :query_dresser]

  def instagram_pictures
    token = '6700053376.fa55fde.f78bb592d8ac4bc884fde11c851cc31c'
    user_id = '6700053376'

    url = URI("https://api.instagram.com/v1/users/#{user_id}/media/recent/?access_token=#{token}")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(url)

    response = http.request(request)
    body = JSON.parse(response.read_body)

    render json: body['data'].each { |d| d[:images]}, status: :ok
  end

  def query_user
    render json: (User.filter_name params['qv']).map {|us| us.simple_info}, status: :ok
  end

  def query_dresser
    render json: (User.filter_dresser params['qv']).map {|us| us.simple_info_dresser}, status: :ok
  end

  def get_address
    render json: Geocoder::search([params[:latitude], params[:longitude]]).first
  end

  def set_stripe_apy_key
    Stripe.api_key = ENV['STRIPE_KEY']
  end

  def change_token
    begin
      current_user.device_token = params[:device_token]
      render json: {success: true}, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  private

  def authenticate_request
    @current_user = AuthorizeApiRequest.call(request.headers).result
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user
  end

  def current_store_auth
    current_user.stores.where(id: params[:store_id]).first
  end

  def current_store
    Store.where(id: params[:store_id]).first
  end
end
