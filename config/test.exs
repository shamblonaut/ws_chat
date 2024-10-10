import Config

config :ws_chat, WsChat.Repo,
  database: "ws_chat_test#{System.get_env("MIX_TEST_PARTITION")}",
  username: "postgres",
  password: "",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
