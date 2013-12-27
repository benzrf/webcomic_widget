webcomic_widget
===============

A simple website for tracking your webcomic updates.

Running
=======

1. Clone the repo.
2. Edit `analytics.haml` to not be my analytics code.
3. Use `bundle install`.
4. Run `create_tables.sql` on your Postgres database of choice.
5. Export values for the environment variables `DATABASE_URL` (`postgres://username:password@host/db_name`) and `SECRET_KEY`.
6. `bundle exec unicorn -p 80`.

