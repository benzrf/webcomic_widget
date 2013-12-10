require 'digest/sha1'

HASH_SALT = ENV['HASH_SALT'] || ''
def login_hash(user, password)
  salted = user.downcase + HASH_SALT + password
  Digest::SHA1.hexdigest(salted)
end

