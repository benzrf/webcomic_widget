require './utils'
require 'sinatra'
require 'sinatra/sequel'

Sequel.extension :core_extensions
database.extension :pg_array

USERS = database[:users]
COMICS = database[:comics]

def user(name)
  USERS.where(name: name).first
end

def add_user(user)
  USERS.insert(user)
end

def update_user(user)
  where = user.slice(:name)
  USERS.where(where).update(user)
end

def comics(name)
  COMICS.where(name: name).all
end

def user_comic(uname, name)
  COMICS.where(uname: uname, name: name).first
end

def user_comics(uname)
  COMICS.where(uname: uname).order(:name).all
end

def update_comic(comic)
  where = comic.slice(:uname, :name)
  COMICS.where(where).update(comic)
end

def add_comic(comic)
  comic = comic.dup
  comic[:schedule] = comic[:schedule].pg_array
  COMICS.insert(comic)
end

