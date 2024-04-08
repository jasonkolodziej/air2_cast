defmodule CastDevice do
  @moduledoc """
  Documentation for `Air2Cast`.
  """
  require IP
  @enforce_keys [:ip_address]
  defstruct mac_address: nil, ip_address: nil, cast_info: nil
  @type t :: %__MODULE__{mac_address: Mac, ip_address: IP}

  defimpl String.Chars, for: CastDevice do
    def to_string(cast_device) do
      "mac_address: #{Mac.to_string(cast_device.mac_address)}, ip_address: #{IP.to_string(cast_device.ip_address)}"
    end
  end


  @spec from_ip_address!(IP.t()) :: CastDevice.t()
  def from_ip_address!(ip_address) do
    from_ip_address(ip_address)
  end

  @spec from_ip_address(IP.t()):: {:ok, t} | {:error, :einval}
  def from_ip_address(ip_address) do
    mac_string = Exile.stream!(["arp", "-n", IP.to_string(ip_address)])
      |> Enum.to_list()
      |> Enum.at(0)
      |> String.split("\n")
      |> Enum.map(
        fn line ->
          String.split(line, " ") |> Enum.at(3) # |> Mac.from_string! # Mac address
        end)
      |> Enum.at(0)
    case Mac.from_string(mac_string) do
      {:ok, mac} -> %CastDevice{mac_address: mac, ip_address: ip_address}
      {:error, _} -> raise ArgumentError, "malformed mac address #{mac_string}"
    end
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

end






defmodule CastDevice.FindDevices do
  @moduledoc """

  """
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

  @spec start!() :: [Client.Device]
  def start!() do
    Client.start()
    #? allows for the registration of a callback
    OnEvent.register()
    Client.query(
      @cast
    )
    # ? Returns a list of devices
    Client.devices()
  end

  # defstruct controller: nil, hw_address: :mac_address
  @doc """

    # Erlang
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
  @spec arp_lookup(IP.t()) :: [Mac.t()]
  def arp_lookup(address) do
    resp = Exile.stream!(["arp", "-a"])
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
            mac: nil,
            # mac: Enum.at(e, 3) |> Mac.from_string!, # 3
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
end
