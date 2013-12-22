webcomic_widget
===============

A simple website for tracking your webcomic updates.

Running
=======

1. Clone the repo.
2. Use `bundle install`.
3. Export values for the environment variables `DATABASE_URL` (must be Postgres), `SECRET_KEY`, and `HASH_SALT` (the latter two should be random values).
4. `bundle exec unicorn -p 80`.

