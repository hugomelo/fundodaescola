require "jwt"

class JsonWebToken
  ALGORITHM = "HS256".freeze
  DEFAULT_EXPIRY = 30.days

  class << self
    def secret
      ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
    end

    def encode(payload, exp: DEFAULT_EXPIRY.from_now)
      payload = payload.dup
      payload[:exp] = exp.to_i
      JWT.encode(payload, secret, ALGORITHM)
    end

    def decode(token)
      body, = JWT.decode(token, secret, true, algorithm: ALGORITHM)
      body.with_indifferent_access
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end
  end
end
