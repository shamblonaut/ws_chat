defmodule Hub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    IO.puts("Starting cowboy server...")

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
