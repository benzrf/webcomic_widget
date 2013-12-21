require './utils'
require './db'
require 'sinatra'
require 'sinatra/json'

helpers do
  def current_login_hash
    login_hash(params['user'], params['password'])
  end

  def current_user
    session['user']
  end
end

SESSION_SECRET = ENV['SECRET_KEY'] || 'dev secret'
set :session_secret, SESSION_SECRET
enable :sessions

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
    logged_in = !!current_user
    redirect to target unless logged_in == should_be
  end
end

# routes

get '/', logged_in: false do
  haml :index
end

get '/register', logged_in: false do
  haml :register
end

post '/register', logged_in: false do
  halt 400, "invalid request" unless params.keys? 'user', 'password', 'email'
  @error = case
  when params['user'].empty?
    "Your username can't be blank."
  when params['user'] !~ /\A\w+\Z/
    "The username '#{params['user']}' contains non-alphanumeric characters."
  when user(params['user'])
    "The username '#{params['user']}' is already taken."
  when params['password'].empty?
    "Your password can't be blank."
  when params['password'] != params['password_confirm']
    "The passwords you entered don't match."
  end
  unless @error
    email = params['email'].empty? ? nil : params['email']
    new_user = {name: params['user'],
                login_hash: current_login_hash,
                email: email}
    add_user(new_user)
    haml :registered
  else
    haml :register
  end
end

get '/login', logged_in: false do
  haml :login
end

post '/login', logged_in: false do
  halt 400, "invalid request" unless params.keys? 'user', 'password'
  @error = case
  when params['user'].empty?
    "You didn't provide a username."
  when params['password'].empty?
    "You didn't provide a password."
  when !(login_user = user(params['user']))
    "Unknown user."
  when login_user[:login_hash] != current_login_hash
    "Incorrect password."
  end
  unless @error
    session.options[:expire_after] = 31536000
    session['user'] = params['user']
    redirect to '/comics/'
  else
    haml :login
  end
end

get '/logout', logged_in: true do
  session.delete :user
  redirect to '/'
end

get '/comics/?', logged_in: true do
  @comics = user_comics(current_user)
  @comics.each do |comic|
    updated = updated? comic
    updates = updates_today? comic
    comic[:updated] = updated
    comic[:updates] = updates
  end
  haml :comics
end

get '/comics/:comic', logged_in: true do
  comic = user_comic(current_user, params['comic'])
  if comic
    comic[:last_checked] = Date.today
    update_comic(comic)
    redirect comic[:url]
  else
    redirect to '/comics/'
  end
end

get '/add_comic', logged_in: true do
  haml :add_comic
end

post '/add_comic', logged_in: true do
  halt 400, "invalid request" unless params.keys? 'name', 'url'
  @error = case
  when params['name'].empty?
    "You didn't provide a name."
  when params['url'].empty?
    "You didn't provide a URL."
  when user_comic(current_user, params['name'])
    "You're already tracking that comic."
  end
  unless @error
    schedule = LDAYS.map {|day| !!params["updates-#{day}"]}
    new_comic = {uname: current_user,
                 name: params['name'],
                 url: params['url'],
                 schedule: schedule,
                 last_checked: nil}
    add_comic(new_comic)
    redirect to '/comics/'
  else
    haml :add_comic
  end
end

post '/complete', provides: 'json' do
  halt 400, "invalid request" unless params['comic'] =~ /.{3,}/
  completions = comic_completions(params['comic'])
  completions.uniq! {|comic| comic[:name]}
  if completions
    suggestions = completions.map {|comic| comic.slice :name, :url, :schedule}
    suggestions.each {|comic| comic[:value] = comic[:name]}
    response = {query: params['comic'],
                suggestions: suggestions}
    json response
  else
    json nil
  end
end

get '/edit_comic/:comic', logged_in: true do
  @comic = user_comic(current_user, params['comic'])
  if @comic
    haml :edit_comic
  else
    redirect to '/comics/'
  end
end

post '/edit_comic/:comic', logged_in: true do
  halt 400, "invalid request" unless params.keys? 'url'
  @comic = user_comic(current_user, params['comic'])
  redirect to '/comics/' unless @comic
  @error = case
  when params['url'].empty?
    "You didn't provide a URL."
  end
  unless @error
    schedule = LDAYS.map {|day| !!params["updates-#{day}"]}
    updated_comic = {uname: current_user,
                     name: params['comic'],
                     url: params['url'],
                     schedule: schedule,
                     last_checked: @comic[:last_checked]}
    update_comic(updated_comic)
    redirect to '/comics/'
  else
    haml :edit_comic
  end
end

get '/delete_comic/:comic', logged_in: true do
  @comic = user_comic(current_user, params['comic'])
  if @comic
    haml :delete_comic
  else
    redirect to '/comics/'
  end
end

post '/delete_comic/:comic', logged_in: true do
  @comic = user_comic(current_user, params['comic'])
  if @comic and params['confirm'] == 'true'
    delete_user_comic(current_user, params['comic'])
  end
  redirect to '/comics/'
end

