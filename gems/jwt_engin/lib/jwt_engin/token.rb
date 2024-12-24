# jwt_ngin/lib/jwt_ngin/token.rb
module JwtEngin
  class Token
    SECRET_KEY = ENV['JWT_SECRET_KEY']

    def self.encode(payload, exp = 24.hours.from_now)
      payload[:exp] = exp.to_i
      JWT.encode(payload, SECRET_KEY)
    end

    def self.decode(token)
      body = JWT.decode(token, SECRET_KEY)[0]
      HashWithIndifferentAccess.new(body)
    rescue
      nil
    end
  end
end
