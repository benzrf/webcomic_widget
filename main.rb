require './utils'
require './db'
require 'sinatra'

helpers do
  def current_user
    session[:user]
  end

  def logged_in?
    !!current_user
  end
end

SESSION_SECRET = ENV['SECRET_KEY'] || 'dev secret'
set :session_secret, SESSION_SECRET
enable :sessions

set :haml, escape_html: true

# should_be denotes whether you should be logged in;
# otherwise is where to redirect you otherwise
set :logged_out_redirect, '/'
set :logged_in_redirect,  '/comics'
set :logged_in do |should_be|
  condition do
    target = should_be ? logged_in_redirect : logged_out_redirect
    redirect to target unless logged_in? == should_be
  end
end

