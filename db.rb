require 'sinatra'
require 'sinatra/sequel'

Sequel.extension :core_extensions
database.extension :pg_array

def user(name)
  database[:users].where(name: name).first
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

