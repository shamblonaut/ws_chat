defmodule Hub.WebsocketHandler do
  @behaviour :cowboy_websocket

  def init(req, _state) do
    client_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    client_ip = :cowboy_req.peer(req) |> elem(0) |> :inet.ntoa() |> to_string()
    {:cowboy_websocket, req, %{id: client_id, ip: client_ip}}
  end

  def websocket_init(state) do
    :ets.insert(:websocket_clients, {self(), state})

    # Send the client their own ID after connection
    {:reply, {:text, Jason.encode!(%{client_id: state.id})}, state}
  end

  def websocket_handle({:text, message}, state) do
    broadcast_message(message, state)
    {:ok, state}
  end

  def websocket_info({:broadcast, from_id, from_ip, message}, state) do
    {:reply, {:text, Jason.encode!(%{from_id: from_id, from_ip: from_ip, message: message})},
     state}
  end

  def websocket_terminate(_reason, _req, _state) do
    :ets.delete(:websocket_clients, self())
    :ok
  end

  defp broadcast_message(message, %{id: from_id, ip: from_ip}) do
    :ets.foldl(
      fn {pid, _}, _ ->
        send(pid, {:broadcast, from_id, from_ip, message})
      end,
      nil,
      :websocket_clients
    )
  end
end
