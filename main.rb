require './utils'
require './db'
require 'sinatra'

helpers do
  def user
    session[:user]
  end

  def logged_in?
    !!user
  end
end

SESSION_SECRET = ENV['SECRET_KEY'] || 'dev secret'
set :session_secret, SESSION_SECRET
enable :sessions

# should_be denotes whether you should be logged in;
# otherwise is where to redirect you otherwise
set :logged_in do |should_be, otherwise|
  condition do
    redirect otherwise unless logged_in? == should_be
  end
end

