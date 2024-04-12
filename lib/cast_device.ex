defmodule CastDevice do
  @moduledoc """
  Documentation for `Air2Cast`.
  """
  require Logger
  require Chromecast
  require Exile.Process, as: ExProcess
  # alias Mdns.Client
  require IP
  @enforce_keys [:ip_address]
  defstruct mac_address: nil, ip_address: nil, device_record: nil, cast_info: nil
  @type t :: %__MODULE__{mac_address: Mac.t, ip_address: IP.t, device_record: Client.Device.t}
  # @type cast_info :: Chromecast

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
    args = case :os.type() do
      {:win32, _} -> ["arp", "/n", IP.to_string(ip_address)]
      {:unix, _} -> ["arp", "-n", IP.to_string(ip_address)]
    end
    {:ok, p} = ExProcess.start_link(args)
    case ExProcess.read(p) do
      {:ok, data} ->
        data
        IO.inspect(data, label: "ExProcess data")
      {:error, _} ->
        ExProcess.await_exit(p)
        struct(CastDevice, ip_address: ip_address)
    end

    # mac_string = data
    #   |> String.split("\n")
    #   |> Enum.map(
    #     fn line ->
    #       String.split(line, " ") |> Enum.at(3) # |> Mac.from_string! # Mac address
    #     end)
    #   |> Enum.at(0)
    # case Mac.from_string(mac_string) do
    #   {:ok, mac} -> struct(CastDevice, mac_address: mac, ip_address: ip_address)
    #   {:error, _} -> struct(CastDevice, mac_address: fix_mac_string(mac_string), ip_address: ip_address) #? raise ArgumentError, "malformed mac address #{mac_string}"
    # end
  end

  # @spec from_device_record!(Client.Device.t()) :: t
  @spec from_device_record!(Client.Device.t) :: t | nil
  def from_device_record!(device_record) do
    Logger.debug("CastDevice.from_device_record! doing struct")
    pay = Chromecast.MdnsPayload.from_struct(device_record.payload)
   tt = case Chromecast.MdnsPayload.is_tv!(pay) do
      false ->
        # IO.inspect(pay, label: "MDNS Payload: ")
        # tt = from_ip_address!(device_record.ip)
        # t.device_record = device_record
        struct(CastDevice,  device_record: device_record, ip_address: device_record.ip)
       true ->
          nil
    end
    tt
  end

  @spec from_device_records(list(Client.Device.t)) :: list(t)
  def from_device_records(records) when is_list(records) do
    for d <- 0..length(records) do
      # ee = Enum.at(records, d)
      IO.puts("#{is_struct(Enum.at(records, d), Client.Device)}")
      [struct(CastDevice, device_record: Enum.at(records, d))]
    end |> List.flatten
  end

  def update!(element) when is_struct(element, CastDevice) do
    if is_struct(element.device_record, Client.Device) do
      struct!(element, ip_address: element.device_record.ip
      )
    end
  end

  @spec start_connection!(
          atom()
          | %{:__struct__ => atom(), :ip => any(), optional(atom()) => any()}
        ) :: t
  def start_connection!(device) do
    IO.inspect(device, label: "start_connection!")
    device = struct(device, cast_info: Chromecast.start_link(device.ip_address))
    Chromecast.state(device.cast_info) |> IO.inspect(label: "start_connection: Chromecast.DeviceState")
    task = Task.async(fn  ->
      mac = CastDevice.ArpData.arp_lookup(device.ip_address)
      Logger.debug(mac, label: "Using an async task to connect and resolve mac address")
     end)

    out = Task.await(task)
    device = struct(device, mac_address: &out.(&1))
  end
end



defmodule CastDevice.ArpData do
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
  defstruct [:hostname, :ip_addr, :mac_addr, :net_interf, :proto_scope, :proto_hw_type]
  use ExConstructor
  require Logger
  require Exile.Stream
  defmacro os_type do
    case :os.type() do
      {:win32, _} -> :win32
      {:unix, _} -> :unix
    end
  end

  defp new!(args) do
    new(args)
  end

  @spec collect() :: Streamer.t() | Map.t()
  def collect when os_type() == :win32, do: collect(["arp", "/a"])
  def collect when os_type() == :unix, do: collect(["arp", "-a"])
  def collect(args) do
    devices = Map.new()
    Exile.stream!(args)
    |> Enum.to_list()
    |> Enum.at(0)
    |> String.trim_trailing("\n")
    |> String.split("\n")
    |> Enum.map(
        fn line ->
          e = String.split(line, " ")
          IO.inspect(line)
          ip_addr = Enum.at(e, 1) |> String.trim_leading("(") |> String.trim_trailing(")") |> IP.from_string!
          devices = Map.put_new(devices, ip_addr,
          new!(
            hostname: Enum.at(e, 0), # 0
            ip_addr: ip_addr, # 1
            # 4 "at"
            #? (ArgumentError) malformed mac address string 60:3e:5f:8b:8:73
            # mac: nil,
            mac_addr: Enum.at(e, 3) |> fix_mac_string!, # |> Mac.from_string!, # 3
            # 4 "on"
            net_interf: Enum.at(e, 5), #5
            proto_scope: Enum.join(Enum.drop(e, 5), " ") #6
          ))
          end)
          |> Enum.reduce(fn val, devices ->  Map.merge(val, devices) end)
  end

  defp fix_mac_string!(mac_string) do
    val = String.split(mac_string, ":")
    if length(val) != 6 do
      Logger.debug("fix_mac_string: something WRONG handling Mac.address #{inspect(val)}")
      Mac.random()
    else
      val |> Enum.map(
      fn piece ->
        if length(String.to_charlist(piece)) != 2 do
          Logger.debug("fix_mac_string: fixing 0#{piece} in #{inspect(val)}")
          "0#{piece}"
        else
          piece
        end
      end
    )
    |> Enum.join(":") |> Mac.from_string!
    end
  end

  @spec arp_lookup(IP.t) :: Mac.t
  def arp_lookup(ip_adder) when os_type() == :win32, do: arp_lookup(ip_adder, ["arp", "/n"])
  def arp_lookup(ip_adder) when os_type() == :unix, do: arp_lookup(ip_adder, ["arp", "-n"])
  @spec arp_lookup(IP.t, list(String.t)) :: Mac.t
  def arp_lookup(ip_adder, args) do
    a = [IP.to_string(ip_adder)]
    a = [args | a] |> List.flatten
    IO.inspect(a)
    respon = Exile.stream!(a)
    |> Enum.to_list()
    IO.inspect(respon, label: "response")
    respon |> Enum.at(0)
    |> String.split("\n")
    |> Enum.map(
        fn line ->
          Logger.debug(line, label: "arp_lookup")
          e = String.split(line, " ")
          Enum.at(e, 3) |> fix_mac_string!
        end)
    |> Enum.at(0)
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
    task = Task.async(
      fn -> CastDevice.ArpData.collect
      end)
    mdns = mdns_client()
    # do_some_other_work()
    # IO.inspect(res, label: "other_handle")
    # devices = Map.new()
    handler = &handle(mdns, &1)
    rr = Task.await(task) |> handler.()

    rr


  end

  def do_some_other_work() do
    mdns_client()
    lazy_handle()
  end

  def lazy_handle do
    receive do
      _ ->
        Client.devices()
    end |> Map.get(String.to_existing_atom(@cast))
  end
  defp mdns_client do
        # Task.start_link()
        Client.start()
        #? allows for the registration of a callback
        OnEvent.register()
        Client.query(
          @cast
        )
        Client.devices()
        # |> Map.get(String.to_existing_atom(@cast))
  end

  def handle(val, lookup) do
    receive do
      {:"_googlecast._tcp.local", device} ->
        # Logger.debug(val)
        dev = CastDevice.from_device_record!(device)
        if is_nil(dev) do
          IO.inspect(label: "dev was Nil :NOTIFY inside process loop")
        else
          IO.inspect(dev, label: "dev was :NOTIFY inside process loop")
          case value = Map.get(lookup, dev.ip_address) do
            nil -> #? there is no suitable device
              IO.inspect(value, label: "Lookup VALUE")
              dev = CastDevice.start_connection!(dev)
            _ ->
              IO.inspect(value.mac_addr, label: "Lookup")
              dev = struct(dev, mac_address: value.mac_addr)
          end
        end
        handle(val, lookup)
      {_, _} -> nil
    after
      5000 ->
        IO.puts("Have been waiting...")
    end
  end

  end
