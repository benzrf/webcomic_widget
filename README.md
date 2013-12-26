webcomic_widget
===============

A simple website for tracking your webcomic updates.

Running
=======

1. Clone the repo.
2. Use `bundle install`.
3. Run `create_tables.sql` on your Postgres database of choice.
4. Export values for the environment variables `DATABASE_URL` (`postgres://username:password@host/db_name`) and `SECRET_KEY`.
5. `bundle exec unicorn -p 80`.

