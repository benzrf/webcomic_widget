require 'sinatra'
require 'sinatra/sequel'

Sequel.extension :core_extensions
database.extension :pg_array

def user(name)
  database[:users].where(name: name).first
end

def comic(uname, name)
  database[:comics].where(uname: uname, name: name).first
end

