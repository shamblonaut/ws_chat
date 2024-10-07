defmodule Hub.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting cowboy server...")

    :ets.new(:websocket_clients, [:set, :public, :named_table])

    children = [
      {Plug.Cowboy,
       scheme: :http,
       plug: Hub.Router,
       options: [
         dispatch: dispatch(),
         port: 4000,
         ip: {0, 0, 0, 0}
       ]}
    ]

    opts = [strategy: :one_for_one, name: Hub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/chat/ws", Hub.WebsocketHandler, []},
         {:_, Plug.Cowboy.Handler, {Hub.Router, []}}
       ]}
    ]
  end
end
