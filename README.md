# WS Chat

A WebSocket-based chat system implemented with Cowboy in Elixir
(with lots of help from GPT and Claude)

## Setup

### Database

> A postgres database is required to be running on `localhost:5432`
> If you already have a database running, you can skip to the Elixir section.
> Otherwise, follow the below steps to get a database up and running.

- Install the `postgres` package with your system package manager

  > It is assumed that your package manager has setup a `postgres` user in your system

- Setup a database for the `postgres` user

```bash
sudo -u postgres initdb --locale=C.UTF8 --encoding=UTF8 '/var/lib/postgres/data'
```

- Start the database server

```bash
postgres -D /var/lib/postgres/data
```

> You may start the database server on boot using `postgresql.service`
> with an init system (like systemd) if you wish

### Elixir

- Install the `elixir` package

- Run the following commands in your terminal:

```bash
git clone https://github.com/shamblonaut/ws_chat
cd ws_chat
mix deps.get
mix ecto.create
mix ecto.migrate
mix run --no-halt
```

Then, open up `http://localhost:4000/chat` in a browser.
Enjoy!

## Channels

For now, to create channels, you must rely on SQL commands

- Ensure that the postgres database is running
- Open up the `psql` interactive SQL terminal (on the dev database)

```bash
psql -h localhost -U postgres -d ws_chat_dev
```

- Run the following command (inside `psql`) to create a channel
  > Replace `'channel-name'` with the name of the new channel

```sql
INSERT INTO channel (name, inserted_at, updated_at)
VALUES ('channel-name', NOW(), NOW());
```
