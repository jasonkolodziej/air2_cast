defmodule Air2Cast do
  @moduledoc """
  Documentation for `Air2Cast`.
  """
  require Logger
  use Application
  require IP
  # require :inet_ext

  defstruct config: nil
  # @ffmpeg
  @doc """
  Hello world.

  ## Examples

      iex> Air2Cast.hello()
      :world

  """
 #  @spec start(_type, _args) :: :ok | :error
  def start(_type, _args) do
    IO.puts "starting"
    children = [
      # The Counter is a child started via Counter.start_link(0)
      #Chromecast.child_spec({192, 168, 2, 219})
      %{
        id: Chromecast,
        start:
          {Chromecast, :start_link,
           [
             {
              {192, 168, 2, 219}
              #  Application.get_env(:bitcoin_network, :ip),
              #  Application.get_env(:bitcoin_network, :port)
             }
           ]}
      }
    ]
    opts = [
      strategy: :one_for_one, name: Chromecast.Supervisor
    ]
    # Now we start the supervisor with the children and a strategy
    {:ok, device} = Supervisor.start_link(children, opts)

    # After started, we can query the supervisor for information
    #? https://elixirschool.com/en/lessons/advanced/otp_supervisors
    Supervisor.count_children(device)
    Chromecast.state(device)


    #=> %{active: 1, specs: 1, supervisors: 0, workers: 1}

    # {:ok, device} = Chromecast.start_link()
    # Chromecast.state(device)
    # Chromecast.state(device)

    # devices = []
    # devices = for d <- 0..length(devs) do
    #   [struct(CastDevice, device_record: Enum.at(devs, d))]
    # end |> List.flatten
    # devices = CastDevice.from_device_records(devs)|> Enum.map(fn el -> CastDevice.update!(el) end)
    # devices = CastDevice.ArpData.collect

    # vv = CastDevice.from_device_records(vals)
    # Logger.debug("start: #{inspect(vv)}")


    # d = %CastDevice{ip_address: , mac_address: nil}

    # CastDevice.from_ip_address!(IP.from_string!("192.168.1.195")) |> IO.puts

    # String.match?(test, other) |> IO.puts
    # Map.take()

  end


end


defmodule Air2Cast.ShairportSync do
 @moduledoc """
  Returns shairport-sync command output
  """
  @shairport_sync "shairport-sync"
@doc """
transcode_audio takes stream input that will be piped to ffmpeg and returns stdout as `Exile.Stream`
"""
@spec run(String.t(), list(String.t())) :: Exile.Stream.t()
def run(config_path, args) do
  if !File.exists?(config_path) && length(args) > 0 do
    [shairport_sync_path() | args] |> Exile.stream!()
  end
  if length(args) > 0 do
    [shairport_sync_path() | ["-c", config_path, args]] |> Exile.stream!()
  else
    [@shairport_sync | ["-c", config_path]] |> Exile.stream!()
  end
end

@doc """
  Read shairport-sync path from config. If unspecified, assume `shairport-sync` is in env $PATH.
  """
  defp shairport_sync_path do
    case Application.get_env(:air2cast, :shairport_sync_path, nil) do
      nil -> System.find_executable(@shairport_sync)
      path -> path
    end
  end
end
