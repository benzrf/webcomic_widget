CREATE EXTENSION IF NOT EXISTS citext;
COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';

CREATE TABLE comics (
    uname citext NOT NULL,
    name citext NOT NULL,
    url text NOT NULL,
    schedule boolean[] NOT NULL,
    last_checked date
);
CREATE TABLE users (
    name citext NOT NULL,
    login_hash text NOT NULL,
    email text
);

ALTER TABLE ONLY comics
    ADD CONSTRAINT comics_pkey PRIMARY KEY (uname, name);
ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (name);
ALTER TABLE ONLY comics
    ADD CONSTRAINT comics_uname_fkey FOREIGN KEY (uname) REFERENCES users(name);

