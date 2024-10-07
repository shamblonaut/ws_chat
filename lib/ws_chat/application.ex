defmodule WsChat.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting cowboy server...")

    :ets.new(:websocket_clients, [:set, :public, :named_table])

    children = [
      {Plug.Cowboy,
       scheme: :http,
       plug: WsChat.Router,
       options: [
         dispatch: dispatch(),
         port: 4000,
         ip: {0, 0, 0, 0}
       ]}
    ]

    opts = [strategy: :one_for_one, name: WsChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/chat/ws", WsChat.WebsocketHandler, []},
         {:_, Plug.Cowboy.Handler, {WsChat.Router, []}}
       ]}
    ]
  end
end
