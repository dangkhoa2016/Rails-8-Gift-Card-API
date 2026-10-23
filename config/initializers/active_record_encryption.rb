# Prefer dedicated encryption keys supplied by the deployment environment.
# In development/test, use stable key material derived from Rails secret_key_base.
# Never commit Rails master.key or any explicit encryption key.
secret = Rails.application.secret_key_base
enc = Rails.application.config.active_record.encryption
enc.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence ||
  Digest::SHA256.hexdigest("wogi-pin-primary:#{secret}")
enc.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence ||
  Digest::SHA256.hexdigest("wogi-pin-deterministic:#{secret}")
enc.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence ||
  Digest::SHA256.hexdigest("wogi-pin-salt:#{secret}")
enc.support_unencrypted_data = false
