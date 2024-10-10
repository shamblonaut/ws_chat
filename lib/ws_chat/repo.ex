defmodule WsChat.Repo do
  use Ecto.Repo,
    otp_app: :ws_chat,
    adapter: Ecto.Adapters.Postgres
end
