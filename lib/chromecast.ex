defmodule Chromecast do
#   alias Chromecast.CastMessage, as: Message
    require Logger
    use Connection
    require GenServer

    use Protobuf, from: Path.expand("../proto/cast_channel.proto", __DIR__)

    @ping "PING"
    @pong "PONG"
    @receiver_status "RECEIVER_STATUS"
    @media_status "MEDIA_STATUS"

    @type streamType :: :BUFFERED | :LIVE | :NONE

#     var getMediaStatus = primitives.PayloadHeaders{Type: "GET_STATUS"}
# var commandMediaPlay = primitives.PayloadHeaders{Type: "PLAY"}
# var commandMediaPause = primitives.PayloadHeaders{Type: "PAUSE"}
# var commandMediaStop = primitives.PayloadHeaders{Type: "STOP"}
# var commandMediaNext = primitives.PayloadHeaders{Type: "NEXT"}
# var commandMediaPrevious = primitives.PayloadHeaders{Type: "PREVIOUS"}
# var commandMediaSeek = primitives.PayloadHeaders{Type: "SEEK"}
# var commandSetSubtitles = primitives.PayloadHeaders{Type: "EDIT_TRACKS_INFO"}
# const eventTypeLoad string = "LOAD"
# const receiverControllerSystemEventGetStatus string = "GET_STATUS"
# const receiverControllerSystemEventSetVolume string = "SET_VOLUME"
# const receiverControllerSystemEventReceiverStatus string = "RECEIVER_STATUS"
# const receiverControllerSystemEventLaunch string = "LAUNCH"
# const receiverControllerSystemEventStop string = "STOP"
# const receiverControllerSystemEventLaunchError string = "LAUNCH"


    defmodule State do
        defstruct media_session: nil,
            session: nil,
            destination_id: "receiver-0",
            ssl: nil,
            ip: nil,
            port: 8009,
            request_id: 0,
            rest: "",
            receiver_status: %{},
            media_status: %{}
    end

    @app_id %{
    # media receiver is a generic media player for urls. Can play images, videos, music, etc.
    # const mediaReceiverAppID string =
        :generic => "CC1AD845",
        :youtube => "233637DE",
        :spotify => "CC32E753",
    }

    @namespace %{
        :con => "urn:x-cast:com.google.cast.tp.connection",
        :heartbeat =>  "urn:x-cast:com.google.cast.tp.heartbeat",
        :receiver => "urn:x-cast:com.google.cast.receiver",
        :cast => "urn:x-cast:com.google.cast.media",
        :message => "urn:x-cast:com.google.cast.player.message",
        :media => "urn:x-cast:com.google.cast.media",
        :youtube => "urn:x-cast:com.google.youtube.mdx",
    }

    #defdelegate child_spec(args), to: GenServer, as: :child_spec

    def start_link(ip \\ {192,168,1,15}) do
        Connection.start_link(__MODULE__, %State{:ip => ip, port:  8009})
    end

    # def start_link({ip, port}) do
    #     Connection.start_link(__MODULE__, %{ip: ip, port: port, rest: ""})
    #   end

    def play(device) do
        GenServer.call(device, :play)
    end

    def pause(device) do
        GenServer.call(device, :pause)
    end

    def set_volume(device, level) do
        GenServer.call(device, {:set_volume, level})
    end

    def state(device) do
        GenServer.call(device, :state)
    end

#  /*
# 	General workflow is
# 	1. message is sent via the request method with unique requestID. adds an inflight chan to wait for event to return.
# 	2. request method calls the send method and wraps the call around some stuff.
# 	3. Client processes events in its active socket stream. If the requestID matches previous one then it sends the
# 	unmarshalled message to the message function.
# 	4. message function processes the event and passes to inflight chan. Also calls any attached listener functions.
# 	5. Request method returns the unmarshalled chromecast event if it worked, timeout if it didn't receive the event in time.
# */

    def create_message(namespace, payload, destination) when payload |> is_map do
        Logger.debug("create_message:@#{namespace}")
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
        Logger.debug("connect_channel:@#{namespace}")
        con = create_message(:con,
            %{:type => "CONNECT", :origin => %{}, :requestId => state.request_id},
            state.destination_id)
        state = send_msg(state.ssl, con, state)
        status = create_message(namespace, %{:type => "GET_STATUS", :requestId => state.request_id}, state.destination_id)
        state = send_msg(state.ssl, status, state)
    end


    defp send_msg(sslSocket, msg, state) do
        Logger.debug("send_msg:#{inspect(msg)}")
        #? https://github.com/pcorey/bitcoin_network/blob/6072b3c71a4eef81540464f7ff2fda5951a331cf/lib/bitcoin_network/node.ex

        case :ssl.send(sslSocket, encode(msg)) do # when sslSocket: sslsocket(), data: iodata()
            :ok ->
                cond do
                    state.request_id > 2000 ->
                        %State{state | :request_id => 0}
                    true ->
                        %State{state | :request_id => state.request_id + 1}
                end

            {:error, reason} ->
                Logger.error "SSL Send Error: #{inspect reason}"
                state
        end
    end

    defp send_message(message, socket) do
        :ssl.send(socket, message)
        # :gen_tcp.send(socket, message)
    end

    defp recv_message(message, socket) do
        :ssl.recv(socket, length(message))
        # :gen_tcp.send(socket, message)
    end

    def connect(_, state) do
        # https://github.com/pcorey/bitcoin_network/blob/6072b3c71a4eef81540464f7ff2fda5951a331cf/lib/bitcoin_network/node.ex#L96
        Logger.debug("connect:")
        #? https://www.erlang.org/doc/man/ssl#handshake_continue-3
        opts = [
            :binary,
            {:active, true},
            {:reuseaddr, true},
            {:verify, :verify_none},
            {:cacerts, :public_key.cacerts_get()}
            ]
        message = create_message(:con,
        %{:type => "CONNECT", :origin => %{}, :requestId => state.request_id},
        state.destination_id) |> encode()
        case :ssl.connect(state.ip, 8009, opts) do
            {:ok, sock} ->
                {:ok, %State{state | ssl: sock}}
            {:error, _} ->
              {:backoff, 1000, state}
                        # _ -> {:backoff, 1000, state}
        end
        case send_message(message, state.ssl) do
            :ok ->
                {:reply, :ok, state}
            {:error, _} = error ->
                 {:disconnect, error, error, state}
        end
        message = create_message(@receiver_status,
                        %{:type => "GET_STATUS", :requestId => state.request_id},
                        state.destination_id) |> encode()
        case send_message(message, state.ssl) do
            :ok ->
                {:reply, :ok, state}
            {:error, _} = error ->
                 {:disconnect, error, error, state}
        end

    end
    # def connect(ip) do
    #     # https://github.com/pcorey/bitcoin_network/blob/6072b3c71a4eef81540464f7ff2fda5951a331cf/lib/bitcoin_network/node.ex#L96
    #     Logger.debug("connect:")
    #     #? https://www.erlang.org/doc/man/ssl#handshake_continue-3
    #     # with {:ok, ssl} <-
    #     :ssl.connect(ip, 8009,[
    #         :binary,
    #         {:active, true},
    #         {:reuseaddr, true},
    #         {:verify, :verify_none},
    #         {:cacerts, :public_key.cacerts_get()}
    #         ])
    # end


    # def init(ip) do
    #     Logger.debug("init:")
    #     {:ok, ssl} = connect(ip)
    #     state = %State{:ssl => ssl, :ip => ip}
    #     # state = %State{:ip => ip}
    #     state = connect_channel(:receiver, state)
    #     state = connect_channel(:media, state)
    #     {:ok, state}
    # end
    @impl true
    def init(state) do
        Logger.debug("init:")
        {:connect, nil, state}
        # {:connect, :init, state}
    end

    @impl true
    def handle_call(:state, _from, state) do
        Logger.debug("handle_call.:state:")
        {:reply, state,state}
        # case recv_message() do
        #     {:ok, _} = ok ->
        #       {:reply, ok, s}
        #     {:error, :timeout} = timeout ->
        #       {:reply, timeout, s}
        #     {:error, _} = error ->
        #       {:disconnect, error, error, s}
        #   end
        # {:state_info, state}
    end

    # TODO: this will require testing, especially for streamType
    def handle_call({:play_media, url, contentType, streamType}, _from, state) do
        Logger.debug("handle_call.:play_media")
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

    def handle_call(:play, _from, state) do
        Logger.debug("handle_call.:play:")
        msg = create_message(:media, %{
            :mediaSessionId => state.media_session,
            :requestId => state.request_id,
            :type => "PLAY"
        }, state.destination_id)
        {:reply, :ok, send_msg(state.ssl, msg, state)}
    end

    def handle_call(:pause, _from, state) do
        Logger.debug("handle_call.:pause:")
        msg = create_message(:media, %{
            :mediaSessionId => state.media_session,
            :requestId => state.request_id,
            :type => "PAUSE"
        }, state.destination_id)
        {:reply, :ok, send_msg(state.ssl, msg, state)}
    end

    def handle_call({:set_volume, level}, _from, state) do
        Logger.debug("handle_call.:set_volume:")
        msg = create_message(:media, %{
            :mediaSessionId => state.media_session,
            :requestId => state.request_id,
            :type => "VOLUME",
            :Volume => %{:level => level, :muted => 0}
        }, state.destination_id)
        {:reply, :ok, send_msg(state.ssl, msg, state)}
    end

    def handle_info({:ssl_closed, _}, state) do
        Logger.debug("handle_info.:ssl_closed:")
        Logger.debug("SSL Connection Closed. Re-opening...")
        # {:ok, ssl}= connect(nil,state)
        # {:ok, ssl} =  connect(state.ip)
        # state = %State{state | :ssl => ssl}
        # state = connect_channel(:receiver, state)
        {:noreply, state}
    end

    # def handle_info({:ssl_closed, _}, {:sslsocket, _, state}) do
    #     Logger.debug("handle_info.:ssl_closed:")
    #     Logger.debug("SSL Connection Closed. Re-opening...")
    #     {:ok, ssl} = connect(nil,state)
    #     # {:ok, ssl} =  connect(state.ip)
    #     state = %State{state | :ssl => ssl}
    #     state = connect_channel(:receiver, state)
    #     {:noreply, state}
    # end

    @impl true
    # def handle_info({:ssl, {sslsocket, new_ssl, _}, data}, state) do
    def handle_info({:ssl, {:sslsocket, new_ssl, _}, data}, state) do
        Logger.debug("handle_info.:ssl:")
        {messages, rest} = decode(state.rest <> data)
        case handle_messages(messages, state) do
            {:disconnect, state} -> {:disconnect, %{state | rest: rest}}
            state -> {:noreply, %{state | rest: rest}}
          end

      state =
        case data |> decode do
          {:error, _} ->
            Logger.debug("handle_info.:ssl:error")
            state
          %{payload_utf8: nil} ->
            Logger.debug("handle_info.:ssl:2")
            state
          %{payload_utf8: payload} ->
            Logger.debug("Chromecast Data: #{payload}")
            payload |> Poison.Parser.parse! |> handle_payload(state)
        end
      {:noreply, state}
    end

    defp handle_messages(messages, state) do
        messages
        # |> Enum.filter(&CastMessage.verify_checksum/1)
        |> Enum.reduce_while(state, fn message, state ->
          case handle_payload(message.parsed_payload, state) do
            {:error, reason, state} -> {:halt, {:disconnect, reason, state}}
            {:ok, state} -> {:cont, state}
          end
        end)
      end

    def handle_payload(%{"type" => @ping} = payload, state) do
        Logger.debug("handle_payload.:ping:")
        msg = create_message(:heartbeat, %{:type => @pong}, "receiver-0")
        send_msg(state.ssl, msg, state)
    end

    def handle_payload(%{"type" => @receiver_status} = payload, state) do
        Logger.debug("handle_payload.:ping:")
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
        {:ok, state}
    end

    def encode(msg) do
        Logger.debug "encode: #{inspect msg}"
        Chromecast.CastMessage.encode(msg)
        # << byte_size(1)::big-unsigned-integer-size(32) >> <> m
    end

    # def decode(<< length::big-unsigned-integer-size(32), rest::binary >> = msg)
    # when length < 102400 do
    #   try do
    #     Chromecast.CastMessage.decode(rest)
    #   rescue
    #     _ ->
    #       Logger.error "ProtoBuf Parse Error: #{inspect msg}"
    #       {:error, :parse_error}
    #   end
    # end

    def decode(<< length::big-unsigned-integer-size(32), rest::binary >> = msg) do
        Logger.debug "ProtoBuf DECODE"
      try do
        &Chromecast.CastMessage.decode(&1)
      rescue
        _ ->
          Logger.error "ProtoBuf Parse Error: #{inspect msg}"
          {:error, :parse_error}
      end
    end
end
