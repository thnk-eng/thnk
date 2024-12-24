module JwtEngin
  class AuthenticateRequest
    def self.call(headers = {})
      new(headers).authenticate
    end

    def initialize(headers = {})
      @headers = headers
    end

    def authenticate
      return error_response('Missing token') if missing_token?
      return error_response('Invalid token') if invalid_token?
      return error_response('User not found') if user.nil?
      user
    end

  private

    attr_reader :headers

    def user
      @user ||= User.find_by(id: decoded_auth_token[:user_id]) if decoded_auth_token
    end

    def decoded_auth_token
      @decoded_auth_token ||= JwtEngin::Token.decode(http_auth_header)
    end

    def http_auth_header
      headers['Authorization'].to_s.split(' ').last
    end

    def missing_token?
      http_auth_header.blank?
    end

    def invalid_token?
      !decoded_auth_token
    end

    def error_response(message)
      { error: message }
    end
  end
end