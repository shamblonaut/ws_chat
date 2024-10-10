defmodule WsChat.WebsocketHandler do
  require Logger

  import Ecto.Query

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
    broadcast_peers()

    schedule_ping()
    send(self(), :broadcast_channels)

    # Send the client their own ID after connection
    {:reply, {:text, Jason.encode!(%{type: "connection", client_id: state.id})}, state}
  end

  def terminate(_reason, _req, state) do
    :ets.delete(:websocket_clients, self())

    Logger.info("Client disconnected: #{state.id} (#{state.ip})")
    broadcast_peers()

    :ok
  end

  # Receive message from client
  def websocket_handle({:text, message}, state) do
    case Jason.decode(message) do
      {:ok, %{"type" => "join", "channelId" => channel_id}} ->
        case WsChat.Repo.get(WsChat.Database.Channel, channel_id) do
          nil ->
            {:reply, {:text, Jason.encode!(%{type: "error", message: "Channel does not exist"})},
             state}

          channel ->
            new_state = %{
              state
              | channels: [%{id: channel.id, name: channel.name} | state.channels] |> Enum.uniq()
            }

            write_client_state(self(), new_state)
            broadcast_peers()

            {:reply,
             {:text,
              Jason.encode!(%{type: "joined", channel: %{id: channel.id, name: channel.name}})},
             new_state}
        end

      {:ok, %{"type" => "leave", "channelId" => channel_id}} ->
        # if channel_id in state.channels do
        if Enum.any?(state.channels, fn %{id: id} -> id == channel_id end) do
          new_state = %{
            state
            | channels: state.channels |> Enum.reject(fn %{id: id} -> id == channel_id end)
          }

          write_client_state(self(), new_state)
          {:reply, {:text, Jason.encode!(%{type: "left", channelId: channel_id})}, new_state}
        else
          {:reply, {:text, Jason.encode!(%{type: "error", message: "Not in channel"})}, state}
        end

      {:ok, %{"type" => "history", "channelId" => channel_id}} ->
        case WsChat.Repo.get(WsChat.Database.Channel, channel_id) do
          nil ->
            {:reply, {:text, Jason.encode!(%{type: "error", message: "Channel does not exist"})},
             state}

          channel ->
            history =
              WsChat.Repo.all(
                from(message in WsChat.Database.Message,
                  where: message.channel_id == ^channel.id,
                  order_by: [asc: message.inserted_at]
                )
              )
              |> Enum.map(fn %{content: content, author: author} ->
                %{content: content, author: author}
              end)

            {:reply,
             {:text, Jason.encode!(%{type: "history", channelId: channel.id, messages: history})},
             state}
        end

      {:ok, %{"type" => "message", "channelId" => channel_id, "content" => content}} ->
        # if channel_id in state.channels do
        if Enum.any?(state.channels, fn %{id: id} -> id == channel_id end) do
          %WsChat.Database.Message{}
          |> WsChat.Database.Message.changeset(%{
            content: content,
            author: state.id,
            channel_id: channel_id
          })
          |> WsChat.Repo.insert()

          channel = state.channels |> Enum.find(fn %{id: id} -> id == channel_id end)
          broadcast_message(content, channel, state)

          {:ok, state}
        else
          {:reply, {:text, Jason.encode!(%{type: "error", message: "Not in channel"})}, state}
        end

      {:ok, %{"type" => type}} ->
        {:reply,
         {:text,
          Jason.encode!(%{type: "error", message: "Could not parse message of type \"#{type}\""})},
         state}

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
  def websocket_info({:broadcast_message, content, author, channel}, state) do
    {:reply,
     {:text,
      Jason.encode!(%{type: "message", content: content, author: author, channelId: channel.id})},
     state}
  end

  def websocket_info(:broadcast_channels, state) do
    channels =
      WsChat.Repo.all(from(channel in WsChat.Database.Channel))
      |> Enum.map(fn %{id: id, name: name} ->
        %{id: id, name: name}
      end)

    {:reply,
     {:text,
      Jason.encode!(%{
        type: "channels",
        channels: channels
      })}, state}
  end

  def websocket_info(:broadcast_peers, state) do
    {:reply,
     {:text,
      Jason.encode!(%{
        type: "peers",
        peers:
          :ets.tab2list(:websocket_clients)
          |> Enum.map(fn {_pid, client_info} ->
            %{
              id: client_info.id,
              ip: client_info.ip,
              channels: client_info.channels
            }
          end)
      })}, state}
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

  defp broadcast_message(content, channel, %{id: author}) do
    Logger.info("[#{channel.name}] #{author}: #{content}")

    :ets.foldl(
      fn {pid, client_state}, _ ->
        # if channel_id in client_state.channels do
        if Enum.any?(client_state.channels, fn %{id: id} -> id == channel.id end) do
          send(pid, {:broadcast_message, content, author, channel})
        end
      end,
      nil,
      :websocket_clients
    )
  end

  defp broadcast_peers do
    :ets.foldl(
      fn {pid, _}, _ ->
        send(pid, :broadcast_peers)
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
