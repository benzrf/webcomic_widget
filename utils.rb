require 'date'
require 'digest/sha1'

class Hash
  def slice(*keys)
    Hash[keys.zip(values_at(*keys))]
  end
  def keys?(*keys)
    keys.flatten.all? {|k| key? k}
  end
end

HASH_SALT = ENV['HASH_SALT'] || ''
def login_hash(user, password)
  salted = user.downcase + HASH_SALT + password
  Digest::SHA1.hexdigest(salted)
end

DAYS = %w{Sunday Monday Tuesday
          Wednesday Thursday Friday
          Saturday}
LDAYS = DAYS.map &:downcase

def updated_between?(schedule, from, til=Date.today)
  return true unless from
  from += 1
  (from..til).each do |day|
    updated_today = schedule[day.wday]
    return true if updated_today
  end
  false
end

def updated?(comic)
  updated_between?(comic[:schedule], comic[:last_checked])
end

def updates_today?(comic)
  comic[:schedule][Date.today.wday]
end

