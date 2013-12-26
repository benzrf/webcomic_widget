require './utils'
require './db'
require 'sinatra'
require 'bcrypt'
require 'rack/csrf'

helpers do
  def gen_hash(pass_source='password')
    'bcrypt$' + BCrypt::Password.create(current_username + params[pass_source])
  end

  def password_correct?(pass_source='password')
    given = params[pass_source]
    hash_col = current_user[:login_hash]
    algo, hash = hash_col.split('$', 2)
    case algo
    when 'sha1'
      given_hash = old_gen_hash(current_username, given)
      hash == given_hash
    when 'bcrypt'
      BCrypt::Password.new(hash) == current_username + given
    end
  end

  def current_username
    params['user'] || session['user'] || ''
  end

  def current_user
    user(current_username)
  end

  def logged_in?
    !!session['user']
  end

  def csrf_tag
    Rack::Csrf.csrf_tag(env)
  end
end

SESSION_SECRET = ENV['SECRET_KEY'] || 'dev secret'
set :session_secret, SESSION_SECRET
enable :sessions

use Rack::Csrf, skip: ['POST:/complete']

set :haml, escape_html: true

# should_be denotes whether you should be logged in;
# otherwise is where to redirect you otherwise
set :logged_out_redirect, '/'
set :logged_in_redirect,  '/comics/'
set :logged_in do |should_be|
  condition do
    target = should_be ?
      settings.logged_out_redirect :
      settings.logged_in_redirect
    redirect to target unless logged_in? == should_be
  end
end

