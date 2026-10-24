module Auth
  class TokenDecoder
    def self.call(token)
      claims, = JWT.decode(token, TokenEncoder.signing_key, true,
        algorithm: TokenEncoder::ALGORITHM, verify_expiration: true,
        verify_iat: true)
      raise JWT::DecodeError, "Missing claims" unless
        claims["sub"].is_a?(String) && claims["sub"].match?(/\A[0-9]+\z/) &&
        %w[admin client].include?(claims["role"]) && claims.key?("exp")
      claims
    end
  end
end
