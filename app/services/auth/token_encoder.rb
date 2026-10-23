module Auth
  class TokenEncoder
    TTL_SECONDS = 3600
    ALGORITHM = "HS256"

    def self.call(user, now: Time.current)
      now_seconds = now.to_i
      claims = {
        sub: user.id.to_s,
        role: user.role,
        iat: now_seconds,
        exp: now_seconds + TTL_SECONDS
      }
      JWT.encode(claims, signing_key, ALGORITHM)
    end

    def self.signing_key
      ENV["JWT_SECRET_KEY"].presence || Rails.application.secret_key_base
    end
  end
end
