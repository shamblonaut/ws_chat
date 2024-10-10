import Config

config :ws_chat,
  ecto_repos: [WsChat.Repo]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
