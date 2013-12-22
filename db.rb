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

def update_user(user, original=user)
  where = original.slice(:name)
  USERS.where(where).update(user)
end

def comics(name)
  COMICS.where(name: name).all
end

def fuzzy_comics(name)
  name = name.downcase
  distance = [3, name.length / 3].max
  COMICS.where{levenshtein(name, lower(:name)) < distance}.all
end

def comic_completions(substr)
  pat = "%#{substr}%"
  COMICS.select(:name, :url, :schedule).
    where(Sequel.like(:name, pat)).
    group_by(:name, :url, :schedule).
    limit(10).all
end

def user_comic(uname, name)
  COMICS.where(uname: uname, name: name).first
end

def user_comics(uname)
  comics = COMICS.where(uname: uname).order(:name).all
  comics.partition {|comic| updated? comic}.flatten 1
end

def update_comic(comic, original=comic)
  comic = comic.dup
  where = original.slice(:uname, :name)
  comic[:schedule] = comic[:schedule].pg_array
  comic[:url].prepend 'http://' unless comic[:url] =~ %r{\A\w+://}
  COMICS.where(where).update(comic)
end

def add_comic(comic)
  comic = comic.dup
  comic[:schedule] = comic[:schedule].pg_array
  comic[:url].prepend 'http://' unless comic[:url] =~ %r{\A\w+://}
  COMICS.insert(comic)
end

def delete_user_comic(uname, name)
  COMICS.where(uname: uname, name: name).delete
end

