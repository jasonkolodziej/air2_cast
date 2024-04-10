defmodule CastDevice do
  @moduledoc """
  Documentation for `Air2Cast`.
  """
  require Logger
  alias Mdns.Client
  # alias Mdns.Client
  require IP
  @enforce_keys [:ip_address]
  defstruct mac_address: nil, ip_address: nil, device_record: nil, cast_info: nil
  @type t :: %__MODULE__{mac_address: Mac.t, ip_address: IP.t, device_record: nil}
  @type cast_info :: Chromecast

  defimpl String.Chars, for: CastDevice do
    def to_string(cast_device) do
      "%CastDevice{mac_address: #{Mac.to_string(cast_device.mac_address)}, ip_address: #{IP.to_string(cast_device.ip_address)}}"
    end
  end


  @spec from_ip_address!(IP.t) :: t
  def from_ip_address!(ip_address) do
    from_ip_address(ip_address)
  end

  @spec from_ip_address(IP.t):: {:ok, t} | {:error, :einval}
  def from_ip_address(ip_address) do
    mac_string =
    case :os.type() do
      {:win32, _} -> Exile.stream!(["arp", "/n", IP.to_string(ip_address)], ignore_epipe: true)
      {:unix, _} -> Exile.stream!(["arp", "-n", IP.to_string(ip_address)], ignore_epipe: true)
    end
      |> Enum.to_list()
      |> Enum.at(0)
      |> String.split("\n")
      |> Enum.map(
        fn line ->
          String.split(line, " ") |> Enum.at(3) # |> Mac.from_string! # Mac address
        end)
      |> Enum.at(0)
    case Mac.from_string(mac_string) do
      {:ok, mac} -> struct(CastDevice, mac_address: mac, ip_address: ip_address)
      {:error, _} -> struct(CastDevice, mac_address: fix_mac_string(mac_string), ip_address: ip_address) #? raise ArgumentError, "malformed mac address #{mac_string}"
    end
  end

  # @spec from_device_record!(Client.Device.t()) :: t
  @spec from_device_record(Client.Device.t) :: t
  def from_device_record(device_record) do
    Logger.debug("CastDevice.from_device_record! doing struct")
    t = from_ip_address!(device_record.ip)
    # t.device_record = device_record
   %CastDevice{t | :device_record => :device_record}
  end

  @spec from_device_records(list(Client.Device.t)) :: list(t)
  def from_device_records(records) when is_list(records) do
    Enum.map(records, fn item -> from_device_record(item) end)
  end

  # @spec arp_lookup :: t
  # defp arp_lookup, do
  # Exile.stream!(args) |> Enum.to_list(["arp", "-n", :ip_address])
  #     |> Enum.at(0)
  #     |> String.split("\n")
  #     |> Enum.map(
  #       fn line ->
  #         String.split(line, " ") |> Enum.at(3) |> Mac.from_string! # Mac address
  #       end)
  #     |> Enum.at(0)
  # end
  defp fix_mac_string(mac_string) do
    val = String.split(mac_string, ":")
    |> Enum.map(
      fn piece ->
        if length(String.to_charlist(piece)) != 2 do
          "0#{piece}"
        else
          piece
        end
      end
    )
    |> Enum.join(":")
    Logger.debug("Fix_mac adder: #{inspect(val)}")
    Mac.from_string!(val)
  end
end






defmodule CastDevice.FindDevices do
  @moduledoc """

  """
  require Logger
  require IP
  # alias Mdns.Client.Device
  require Mdns.Client, as: Client
  require Mdns.EventManager, as: OnEvent
  # @type Device :: Mdns.Client.Device
  @cast "_googlecast._tcp.local"
  @doc """
  Hello world.

  ## Examples

      iex> Air2Cast.hello()
      :world

  """

  @spec start!() :: list(Client.Device.t)
  def start!() do
    Client.start()
    #? allows for the registration of a callback
    OnEvent.register()
    Client.query(
      @cast
    )
    receive do
      # ? Returns a list of devices
      _ -> Client.devices()
    end
    |> Map.get(String.to_existing_atom(@cast))
  end

  def handle_info({:udp, _socket, ip, _port, packet}, state) do
    {:noreply, handle_packet(ip, packet, state)}
  end

  def handle_packet(ip, packet, state) do
    record = DNS.Record.decode(packet)

    case record.header.qr do
      true -> handle_response(ip, record, state)
      _ -> state
    end
  end

  def handle_response(ip, record, state) do
    Logger.debug("hookmDNS got response: #{inspect(record)}")
    device = Client.get_device(ip, record, state)

    devices =
      Enum.reduce(state.queries, %{:other => []}, fn query, acc ->
        cond do
          Enum.any?(device.services, fn service -> String.ends_with?(service, query) end) ->
            {namespace, devices} = Client.create_namespace_devices(query, device, acc, state)
            Mdns.EventManager.notify({namespace, device})
            Logger.debug("mDNS device: #{inspect({namespace, device})}")
            devices

          true ->
            Map.merge(acc, state.devices)
        end
      end)

    %Mdns.Client.State{state | :devices => devices}
  end

  @doc """
  Parses output from the arp command to a struct.
  ## Example

  some.localdomain (192.168.4.4) at Xx:Aa:Bb:Cc:Dd:Ee on en0 ifscope [ethernet]
  {hostname} ({ip_address}) at {mac_addr} on {interface} {scope} {scope_type}
  other = "#{:hostname} (#{:ip_addr}) at #{:mac_addr} on #{:net_interf} #{:proto_scope} [#{:proto_hw_type}]"
  ## Erlang
    # %%-------------------------------------------------------------------------
    # %% Lookup the MAC address of an IP
    # %%-------------------------------------------------------------------------
    arplookup({A1, A2, A3, A4}) ->
        arplookup(inet_parse:ntoa({A1, A2, A3, A4}));
    arplookup(IPaddr) when is_list(IPaddr) ->
        {ok, FH} = file:open("/proc/net/arp", [read, raw]),
        MAC = arplookup_iter(FH, IPaddr),
        file:close(FH),
        MAC.

    arplookup_iter(FH, IPaddr) ->
        arplookup_iter_1(FH, IPaddr, file:read_line(FH)).

    arplookup_iter_1(FH, IPaddr, {ok, Line}) ->
        case string:tokens(Line, "\s\n") of
            [IPaddr, _HWType, _Flags, MAC | _] ->
                list_to_tuple([
                    erlang:list_to_integer(E, 16)
                || E <- string:tokens(MAC, ":")
                ]);
            _ ->
                arplookup_iter(FH, IPaddr)
        end;
    arplookup_iter_1(_FH, _IPaddr, eof) ->
        false.
  """
  @spec arp_lookup(IP.t() | none()) :: [Mac.t()]
  def arp_lookup(address) when IP.is_ip(address) == true do
    resp = Exile.stream!(["arp", "-n", IP.to_string(address)])
    |> Enum.to_list()
    |> Enum.at(0)
    |> String.split("\n")
    |> Enum.map(
        fn line ->
          e = String.split(line, " ")
          %{
            hostname: Enum.at(e, 0), # 0
            ip_addr: Enum.at(e, 1) |> String.trim_leading("(") |> String.trim_trailing(")") |> IP.from_string!, # 1
            # 4 "at"
            #? (ArgumentError) malformed mac address string 60:3e:5f:8b:8:73
            # mac: nil,
            mac: Enum.at(e, 3), # |> Mac.from_string!, # 3
            # 4 "on"
            interface_name: Enum.at(e, 5), #5
            layer: Enum.join(Enum.drop(e, 5), " ") #6
          }
        end)
        |> Enum.filter(
        fn struc ->
          struc[:ip_addr] === address
        end)
       |> Enum.map(
        fn s-> s[:mac]
        end)
        resp
  end

  def arp_lookup(address) when IP.is_ip(address) == false do
    IO.puts("looking up all")
    resp = Exile.stream!(["arp", "-a"])
    |> Enum.to_list()
    |> Enum.at(0)
    |> String.split("\n")
    |> Enum.map(
        fn line ->
          e = String.split(line, " ")
          %{
            hostname: Enum.at(e, 0), # 0
            ip_addr:  Enum.at(e, 1) |> String.replace_prefix("(", "") |> String.replace_suffix(")", ""), # 1
            # 4 "at"
            #? (ArgumentError) malformed mac address string 60:3e:5f:8b:8:73
            # mac: nil,
            mac: Enum.at(e, 3), # |> Mac.from_string!, # 3
            # 4 "on"
            interface_name: Enum.at(e, 5), #5
            layer: Enum.join(Enum.drop(e, 5), " ") #6
          }
        end)
        resp
  end

  end
