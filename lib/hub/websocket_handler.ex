defmodule Hub.WebsocketHandler do
  require Logger

  @behaviour :cowboy_websocket

  @ping_interval 10_000
  @pong_timeout 5_000

  def init(req, _state) do
    client_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    client_ip = :cowboy_req.peer(req) |> elem(0) |> :inet.ntoa() |> to_string()

    {:cowboy_websocket, req,
     %{id: client_id, ip: client_ip, last_pong: :os.system_time(:millisecond)}}
  end

  def websocket_init(state) do
    :ets.insert(:websocket_clients, {self(), state})

    Logger.info("Client connected: #{state.id} (#{state.ip})")
    schedule_ping()

    # Send the client their own ID after connection
    {:reply, {:text, Jason.encode!(%{client_id: state.id})}, state}
  end

  def terminate(_reason, _req, state) do
    Logger.info("Client disconnected: #{state.id} (#{state.ip})")

    :ets.delete(:websocket_clients, self())
    :ok
  end

  # Receive message from client
  def websocket_handle({:text, message}, state) do
    if message == "pong" do
      {:ok, %{state | last_pong: :os.system_time(:millisecond)}}
    else
      broadcast_message(message, state)
      {:ok, state}
    end
  end

  # Fallback
  def websocket_handle(_frame, _req, state) do
    {:ok, state}
  end

  # Broadcast message to all clients
  def websocket_info({:broadcast, from_id, from_ip, message}, state) do
    Logger.info("#{from_id} (#{from_ip}): #{message}")

    {:reply, {:text, Jason.encode!(%{from_id: from_id, from_ip: from_ip, message: message})},
     state}
  end

  def websocket_info(:ping, state) do
    # Logger.info("DEBUG: Ping #{state.id} @ #{:os.system_time(:millisecond)}")
    schedule_pong_check()
    {:reply, {:text, "ping"}, state}
  end

  def websocket_info(:pong_check, state) do
    current_time = :os.system_time(:millisecond)

    if current_time - state.last_pong > @pong_timeout do
      Logger.info("Client timed out: #{state.id}")
      {:stop, state}
    else
      # Logger.info("DEBUG: Pong #{state.id} @ #{:os.system_time(:millisecond)}")
      schedule_ping()
      {:ok, state}
    end
  end

  # Fallback
  def websocket_info(_info, state) do
    {:ok, state}
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

  defp schedule_ping do
    Process.send_after(self(), :ping, @ping_interval)
  end

  defp schedule_pong_check do
    Process.send_after(self(), :pong_check, @pong_timeout)
  end
end
