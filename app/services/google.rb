require 'uri'
require 'net/http'
require "addressable/uri"

class Google
  prepend SimpleCommand

  class << self
    def exchange_token(token)
      url = URI('https://www.googleapis.com/oauth2/v4/token')

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Post.new(url)
      request['content-type'] = 'application/x-www-form-urlencoded'
      request['cache-control'] = 'no-cache'
      body = {
          code: token,
          redirec_uri: 'https://fonzy.herokuapp.com/omniauth/google_oauth2/callback',
          client_id: ENV['GOOGLE_KEY'],
          client_secret: ENV['GOOGLE_SECRET'],
          scope: '',
          grant_type: 'authorization_code'
      }
      uri = Addressable::URI.new
      uri.query_values = body
      request.body = uri.query

      response = http.request(request)
      JSON.parse(response.read_body)["access_token"]
    end

    def get_object(token)
      url = URI("https://www.googleapis.com/oauth2/v2/userinfo")

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(url)
      request["authorization"] = "Bearer #{exchange_token token}"
      request["cache-control"] = 'no-cache'

      response = http.request(request)
      return JSON.parse(response.read_body) unless response.read_body.include? 'error'
      nil
    end
  end
end
