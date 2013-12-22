require './utils'
require './db'
require 'sinatra'
require 'sinatra/json'
require 'rack/csrf'
require 'bcrypt'

helpers do
  def gen_hash(pass_source='password')
    'bcrypt$' + BCrypt::Password.create(current_user + params[pass_source])
  end

  def password_correct?(pass_source='password')
    given = params[pass_source]
    hash_col = user(current_user)[:login_hash]
    algo, hash = hash_col.split('$', 2)
    case algo
    when 'sha1'
      given_hash = old_gen_hash(current_user, given)
      hash == given_hash
    when 'bcrypt'
      BCrypt::Password.new(hash) == current_user + given
    end
  end

  def current_user
    params['user'] || session['user']
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
                login_hash: gen_hash,
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
  when !password_correct?
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
    halt 404
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
    completions.each {|comic| comic[:value] = comic[:name]}
    response = {query: params['comic'],
                suggestions: completions}
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
    halt 404
  end
end

post '/edit_comic/:comic', logged_in: true do
  halt 400, "invalid request" unless params.keys? 'url'
  @comic = user_comic(current_user, params['comic'])
  halt 404 unless @comic
  @error = case
  when params['name'].empty?
    "You didn't provide a name."
  when params['url'].empty?
    "You didn't provide a URL."
  end
  unless @error
    schedule = LDAYS.map {|day| !!params["updates-#{day}"]}
    updated_comic = {uname: current_user,
                     name: params['name'],
                     url: params['url'],
                     schedule: schedule,
                     last_checked: @comic[:last_checked]}
    update_comic(updated_comic, @comic)
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
    halt 404
  end
end

post '/delete_comic/:comic', logged_in: true do
  @comic = user_comic(current_user, params['comic'])
  halt 404 unless @comic
  if @comic and params['confirm'] == 'true'
    delete_user_comic(current_user, params['comic'])
  end
  redirect to '/comics/'
end

get '/edit_account', logged_in: true do
  @user = user(current_user)
  haml :edit_account
end

post '/edit_account', logged_in: true do
  needed_params = 'password', 'new_password', 'email'
  halt 400, "invalid request" unless params.keys? needed_params
  @user = user(current_user)
  @error = case
  when !password_correct?
    "Incorrect password."
  when params['new_password'] != params['password_confirm']
    "The new passwords you entered don't match."
  end
  unless @error
    email = params['email'].empty? ? nil : params['email']
    updated_user = {name: current_user,
                    email: email}
    unless params['new_password'].empty?
      updated_user[:login_hash] = gen_hash('new_password')
    end
    update_user(updated_user)
    redirect to '/comics/'
  else
    haml :edit_account
  end
end

