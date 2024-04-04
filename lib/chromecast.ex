defmodule Chromecast do
  @moduledoc """
  Documentation for `Chromecast`.
  """
  require Logger
  require Poison
  require MIME
  require URI
  use GenServer
  use Protobuf, from: Path.expand("../proto/cast_channel.proto", __DIR__)

  @ping "PING"
  @pong "PONG"
  @receiver_status "RECEIVER_STATUS"
  @media_status "MEDIA_STATUS"

  defmodule State do
    @moduledoc """
    Documentation for `Chromecast.State`.
    """
      defstruct media_session: nil,
          session: nil,
          destination_id: "receiver-0",
          ssl: nil,
          ip: nil,
          request_id: 0,
          receiver_status: %{},
          media_status: %{}
  end
  @type streamType :: :BUFFERED | :LIVE | :NONE
  @namespace %{
      :con => "urn:x-cast:com.google.cast.tp.connection",
      :receiver => "urn:x-cast:com.google.cast.receiver",
      :cast => "urn:x-cast:com.google.cast.media",
      :heartbeat =>  "urn:x-cast:com.google.cast.tp.heartbeat",
      :message => "urn:x-cast:com.google.cast.player.message",
      :media => "urn:x-cast:com.google.cast.media",
      :youtube => "urn:x-cast:com.google.youtube.mdx",
  }

  @doc """
  :ok

  ## Examples

    iex> {:ok, device} = Chromecast.start_link {192,168,1,138}
    {:ok, #PID<0.225.0>}

  """
  @spec start_link() :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(ip \\ {192,168,1,15}) do
      GenServer.start_link(__MODULE__, ip)
  end

  @spec play(atom() | pid() | {atom(), any()} | {:via, atom(), any()}) :: any()
  def play(device) do
      GenServer.call(device, :play)
  end

  def pause(device) do
      GenServer.call(device, :pause)
  end

  def stop(device) do
    GenServer.call(device, :stop)
  end

  def set_volume(device, level) do
      GenServer.call(device, {:set_volume, level})
  end

  def state(device) do
      GenServer.call(device, :state)
  end

  def create_message(namespace, payload, destination) when payload |> is_map do
      Chromecast.CastMessage.new(
          protocol_version: :CASTV2_1_0,
          source_id: "sender-0",
          destination_id: destination,
          payload_type: :STRING,
          namespace: @namespace[namespace],
          payload_utf8: Poison.encode!(payload)
      )
  end

  def connect_channel(namespace, state) do
      con = create_message(:con, %{:type => "CONNECT", :origin => %{}, :requestId => state.request_id}, state.destination_id)
      state = send_msg(state.ssl, con, state)
      status = create_message(namespace, %{:type => "GET_STATUS", :requestId => state.request_id}, state.destination_id)
      state = send_msg(state.ssl, status, state)
  end

  def send_msg(ssl, msg, state) do
      case :ssl.send(ssl, encode(msg)) do
          :ok ->
              cond do
                  state.request_id > 2000 -> %State{state | :request_id => 0}
                  true -> %State{state | :request_id => state.request_id + 1}
              end
          {:error, reason} ->
              Logger.error "SSL Send Error: #{inspect reason}"
              state
      end
  end

  def connect(ip) do
      {:ok, ssl} = :ssl.connect(ip, 8009, [:binary, {:reuseaddr, true}])
  end

  def init(ip) do
      {:ok, ssl} = connect(ip)
      state = %State{:ssl => ssl, :ip => ip}
      state = connect_channel(:receiver, state)
      {:ok, state}
  end

  def handle_call(:state, _from, state) do
      {:reply, state, state}
  end

  def handle_call(:play, _from, state) do
      msg = create_message(:media, %{
          :mediaSessionId => state.media_session,
          :requestId => state.request_id,
          :type => "PLAY"
      }, state.destination_id)
      {:reply, :ok, send_msg(state.ssl, msg, state)}
  end

  def handle_call(:pause, _from, state) do
      msg = create_message(:media, %{
          :mediaSessionId => state.media_session,
          :requestId => state.request_id,
          :type => "PAUSE"
      }, state.destination_id)
      {:reply, :ok, send_msg(state.ssl, msg, state)}
  end

  # TODO: this will require testing, especially for streamType
  def handle_call({:play_media, url, contentType, streamType}, _from, state) do
    msg = create_message(:media, %{
        :mediaSessionId => state.media_session,
        :requestId => state.request_id,
        :type => "LOAD",
        :MediaInformation => %{:contentId => url,
            :contentType => MIME.type(contentType),
            :streamType => streamType}
    }, state.destination_id)
    {:reply, :ok, send_msg(state.ssl, msg, state)}
  end

#   defp stream_type(streamType) do
#     case  do
#          ->

#     end
#   end

  def handle_call({:set_volume, level}, _from, state) do
      msg = create_message(:media, %{
          :mediaSessionId => state.media_session,
          :requestId => state.request_id,
          :type => "VOLUME",
          :Volume => %{:level => level, :muted => 0}
      }, state.destination_id)
      {:reply, :ok, send_msg(state.ssl, msg, state)}
  end

  def handle_call(:stop, _from, state) do
    msg = create_message(:media, %{
        :mediaSessionId => state.media_session,
        :requestId => state.request_id,
        :type => "STOP",
    }, state.destination_id)
    {:reply, :ok, send_msg(state.ssl, msg, state)}
end

  def handle_info({:ssl_closed, _}, state) do
      Logger.debug("SSL Connection Closed. Re-opening...")
      {:ok, ssl} = connect(state.ip)
      state = %State{state | :ssl => ssl}
      state = connect_channel(:receiver, state)
      {:noreply, state}
  end

  def handle_info({:ssl_closed, _}, {:sslsocket, _, state}) do
      Logger.debug("SSL Connection Closed. Re-opening...")
      {:ok, ssl} = connect(state.ip)
      state = %State{state | :ssl => ssl}
      state = connect_channel(:receiver, state)
      {:noreply, state}
  end

  def handle_info({:ssl, {sslsocket, new_ssl, _}, data}, state) do
    state =
      case data |> decode do
        {:error, _} -> state
        %{payload_utf8: nil} -> state
        %{payload_utf8: payload} ->
          Logger.debug("Chromecast Data: #{payload}")
          payload |> Poison.Parser.parse! |> handle_payload(state)
      end
    {:noreply, state}
  end

  def handle_payload(%{"type" => @ping} = payload, state) do
      msg = create_message(:heartbeat, %{:type => @pong}, "receiver-0")
      send_msg(state.ssl, msg, state)
  end

  def handle_payload(%{"type" => @receiver_status} = payload, state) do
      case payload["status"]["applications"] do
          nil -> state
          other ->
              app = Enum.at(other, 0)
              cond do
                  app["transportId"] != state.destination_id ->
                      state = %State{state | :destination_id => app["transportId"], :session => app["sessionId"]}
                      state = connect_channel(:media, state)
                      %State{state | :receiver_status => payload}
                  true -> state
              end
      end
  end

  def handle_payload(%{"type" => @media_status} = payload, state) do
      status =
        case Enum.at(payload["status"], 0) do
          nil -> state.media_status
          %{} = stat -> Map.merge(state.media_status, stat)
        end
      %State{state | :media_status => status, :media_session => status["mediaSessionId"]}
  end

  def handle_payload(%{"backendData" => status} = payload, state) do
      %State{state | :media_status => payload}
  end

  def handle_payload(%{} = payload, state) do
      Logger.debug "Unknown Payload: #{inspect payload}"
      state
  end

  def encode(msg) do
      m = Chromecast.CastMessage.encode(msg)
      << byte_size(m)::big-unsigned-integer-size(32) >> <> m
  end

  def decode(<< length::big-unsigned-integer-size(32), rest::binary >> = msg)
  when length < 102400 do
    try do
      Chromecast.CastMessage.decode(rest)
    rescue
      _ ->
        Logger.error "ProtoBuf Parse Error: #{inspect msg}"
        {:error, :parse_error}
    end
  end

  def decode(<< length::big-unsigned-integer-size(32), rest::binary >> = msg) do
    try do
      Chromecast.CastMessage.decode(msg)
    rescue
      _ ->
        Logger.error "ProtoBuf Parse Error: #{inspect msg}"
        {:error, :parse_error}
    end
  end
end
