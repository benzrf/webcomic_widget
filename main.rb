require './db'
require './utils'
require './sinatra_utils'
require 'sinatra'
require 'sinatra/json'

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
  when current_username.empty?
    "Your username can't be blank."
  when current_username !~ /\A\w+\Z/
    "The username '#{current_username}' contains non-alphanumeric characters."
  when current_user
    "The username '#{current_username}' is already taken."
  when params['password'].empty?
    "Your password can't be blank."
  when params['password'] != params['password_confirm']
    "The passwords you entered don't match."
  end
  unless @error
    email = params['email'].empty? ? nil : params['email']
    new_user = {name: current_username,
                login_hash: gen_hash,
                email: email,
                profile_id: gen_profile_id(current_username)}
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
  when current_username.empty?
    "You didn't provide a username."
  when params['password'].empty?
    "You didn't provide a password."
  when !current_user
    "Unknown user."
  when !password_correct?
    "Incorrect password."
  end
  unless @error
    session.options[:expire_after] = 31536000
    session['user'] = current_username
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
  @comics = user_comics(current_username)
  @comics.each do |comic|
    updated = updated? comic
    updates = updates_today? comic
    comic[:updated] = updated
    comic[:updates] = updates
  end
  haml :comics
end

get %r(/comics/(.+)), logged_in: true do |par_comic|
  comic = user_comic(current_username, par_comic)
  halt 404 unless comic
  comic[:last_checked] = (Time.now.utc - (5 * 60 * 60)).to_date
  update_comic(comic)
  redirect comic[:url]
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
  when user_comic(current_username, params['name'])
    "You're already tracking that comic."
  end
  unless @error
    schedule = LDAYS.map {|day| !!params["updates-#{day}"]}
    new_comic = {uname: current_username,
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

get %r(/edit_comic/(.+)), logged_in: true do |par_comic|
  @comic = user_comic(current_username, par_comic)
  halt 404 unless @comic
  haml :edit_comic
end

post %r(/edit_comic/(.+)), logged_in: true do |par_comic|
  halt 400, "invalid request" unless params.keys? 'url'
  @comic = user_comic(current_username, par_comic)
  halt 404 unless @comic
  @error = case
  when params['name'].empty?
    "You didn't provide a name."
  when params['url'].empty?
    "You didn't provide a URL."
  end
  unless @error
    schedule = LDAYS.map {|day| !!params["updates-#{day}"]}
    updated_comic = {uname: current_username,
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

get %r(/delete_comic/(.+)), logged_in: true do |par_comic|
  @comic = user_comic(current_username, par_comic)
  halt 404 unless @comic
  haml :delete_comic
end

post %r(/delete_comic/(.+)), logged_in: true do |par_comic|
  @comic = user_comic(current_username, par_comic)
  halt 404 unless @comic
  if @comic and params['confirm'] == 'true'
    delete_user_comic(current_username, par_comic)
  end
  redirect to '/comics/'
end

get '/edit_account', logged_in: true do
  @user = current_user
  haml :edit_account
end

post '/edit_account', logged_in: true do
  needed_params = 'password', 'new_password', 'email'
  halt 400, "invalid request" unless params.keys? needed_params
  @error = case
  when !password_correct?
    "Incorrect password."
  when params['new_password'] != params['password_confirm']
    "The new passwords you entered don't match."
  end
  unless @error
    email = params['email'].empty? ? nil : params['email']
    updated_user = {name: current_username,
                    email: email}
    unless params['new_password'].empty?
      updated_user[:login_hash] = gen_hash('new_password')
    end
    update_user(updated_user)
    redirect to '/comics/'
  else
    @user = current_user
    haml :edit_account
  end
end

get '/profiles/:profile_id' do
  @user = profile_id_user(params['profile_id'])
  halt 404 unless @user
  @profile_comics = user_profile_id_comics(params['profile_id'])
  @cur_comics = user_comics(current_username)
  haml :profile
end

post '/copy_comic', logged_in: true do
  halt 400, "invalid request" unless params.keys? 'profile_id', 'comic'
  comics = user_profile_id_comics(params['profile_id'])
  copied_comic = comics.detect {|comic| comic[:name] == params['comic']}
  halt 400 unless copied_comic
  copied_comic[:uname] = current_username
  copied_comic[:last_checked] = nil
  add_comic(copied_comic)
  redirect to "/profiles/#{params['profile_id']}"
end

