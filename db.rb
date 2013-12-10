require './utils'
require 'sinatra'
require 'sinatra/sequel'

Sequel.extension :core_extensions
database.extension :pg_array

def user(name)
  database[:users].where(name: name).first
end

def update_user(user)
  where = user.slice(:name)
  database[:users].where(where).update(user)
end

def comics(name)
  database[:comics].where(name: name).all
end

def user_comic(uname, name)
  database[:comics].where(uname: uname, name: name).first
end

def user_comics(uname)
  database[:comics].where(uname: uname).all
end

def update_comic(comic)
  where = comic.slice(:uname, :name)
  database[:comics].where(where).update(comic)
end

