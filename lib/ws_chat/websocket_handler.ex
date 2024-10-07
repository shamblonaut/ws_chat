defmodule WsChat.WebsocketHandler do
  require Logger

  @behaviour :cowboy_websocket

  @ping_interval 30_000
  @pong_timeout 5_000

  def init(req, _state) do
    client_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    client_ip = :cowboy_req.peer(req) |> elem(0) |> :inet.ntoa() |> to_string()

    {:cowboy_websocket, req,
     %{id: client_id, ip: client_ip, last_pong: :os.system_time(:millisecond), channels: []}}
  end

  def websocket_init(state) do
    write_client_state(self(), state)

    Logger.info("Client connected: #{state.id} (#{state.ip})")
    schedule_ping()

    # Send the client their own ID after connection
    {:reply, {:text, Jason.encode!(%{type: "connection", client_id: state.id})}, state}
  end

  def terminate(_reason, _req, state) do
    Logger.info("Client disconnected: #{state.id} (#{state.ip})")

    :ets.delete(:websocket_clients, self())
    :ok
  end

  # Receive message from client
  def websocket_handle({:text, message}, state) do
    case Jason.decode(message) do
      {:ok, %{"type" => "join", "channel" => channel}} ->
        new_state = %{state | channels: [channel | state.channels] |> Enum.uniq()}
        write_client_state(self(), new_state)
        {:reply, {:text, Jason.encode!(%{type: "joined", channel: channel})}, new_state}

      {:ok, %{"type" => "leave", "channel" => channel}} ->
        new_state = %{state | channels: state.channels -- [channel]}
        write_client_state(self(), new_state)
        {:reply, {:text, Jason.encode!(%{type: "left", channel: channel})}, new_state}

      {:ok, %{"type" => "message", "channel" => channel, "content" => content}} ->
        if channel in state.channels do
          broadcast_message(channel, content, state)
          {:ok, state}
        else
          {:reply, {:text, Jason.encode!(%{type: "error", message: "Not in channel"})}, state}
        end

      _ ->
        {:reply, {:text, Jason.encode!(%{type: "error", message: "Invalid message format"})},
         state}
    end
  end

  # Handle pong from client
  def websocket_handle(:pong, state) do
    # Logger.info("DEBUG: Pong #{state.id} @ #{:os.system_time(:millisecond)}")
    {:ok, %{state | last_pong: :os.system_time(:millisecond)}}
  end

  # Fallback
  def websocket_handle(_frame, _req, state) do
    {:ok, state}
  end

  # Broadcast message to all clients
  def websocket_info({:broadcast, channel, from_id, from_ip, content}, state) do
    Logger.info("[#{channel}] #{from_id} (#{from_ip}): #{content}")

    if channel in state.channels do
      {:reply,
       {:text,
        Jason.encode!(%{type: "message", from_id: from_id, from_ip: from_ip, content: content})},
       state}
    else
      {:ok, state}
    end
  end

  # Send ping to client
  def websocket_info(:ping, state) do
    # Logger.info("DEBUG: Ping #{state.id} @ #{:os.system_time(:millisecond)}")
    schedule_pong_check()
    {:reply, :ping, state}
  end

  # Check if client sent back a pong
  def websocket_info(:pong_check, state) do
    current_time = :os.system_time(:millisecond)

    # Logger.info("DEBUG: Pong check @ #{:os.system_time(:millisecond)}")

    # The last pong is compared with twice the @pong_timeout due to
    # :pong_check being executed after a delay of @pong_timeout
    if current_time - state.last_pong > @pong_timeout * 2 do
      Logger.info("Client timed out: #{state.id}")
      {:stop, state}
    else
      schedule_ping()
      {:ok, state}
    end
  end

  # Fallback
  def websocket_info(_info, state) do
    {:ok, state}
  end

  defp broadcast_message(channel, content, %{id: from_id, ip: from_ip}) do
    :ets.foldl(
      fn {pid, client_state}, _ ->
        if channel in client_state.channels do
          send(pid, {:broadcast, channel, from_id, from_ip, content})
        end
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

  # Note: `last_pong` state is deliberately not written to ets,
  # as it is not required to be so as of yet
  defp write_client_state(pid, state) do
    :ets.insert(:websocket_clients, {pid, state})
  end
end
