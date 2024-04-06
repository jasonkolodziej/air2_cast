defmodule CastDevice do
  @moduledoc """
  Documentation for `Air2Cast`.
  """

  @type mac_address :: Mac.t()
  defmodule ArpData do
    @derive {Inspect, only: :hostname}
    @type t :: %__MODULE__{hostname: nil | String, # 0
        ip_addr: IP| nil,
        # 4 "at"
        #? (ArgumentError) malformed mac address string 60:3e:5f:8b:8:73
        mac: Mac|nil,
        # mac: Enum.at(e, 3) |> Mac.from_string!, # 3
        # 4 "on"
        interface_name: String|nil, #5
        layer: String|nil #6
      }

end

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
    resp = Exile.stream!(["arp", "-a"]) |>
    Enum.to_list()
    resp |> Enum.at(0) |>
    String.split("\n") |>
    Enum.map(maker) |> Enum.reduce(
        fn struc ->
          struc[:ip_addr] === address
        end) |> Enum.map(fn s-> s[:mac] end)

        resp
  end
  defp maker(line) do
      e = String.split(line, " ")
      s = %ArpData{
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
      try do
        s.mac = Enum.at(e, 3) |> Mac.from_string!
      rescue ArgumentError -> nil
      catch
        a ->
          IO.puts("OHHHH #{inspect(a)}")
      after
        s.mac = Enum.at(e, 3)
      end
    end
end
