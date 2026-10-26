Rails.application.config.filter_parameters += [
  :pin, :password, :password_digest, :access_token, :jwt, :authorization,
  :idempotency_key, :activation_number
]
