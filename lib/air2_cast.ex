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
    vals = CastDevice.FindDevices.start!()
    Logger.debug("start: #{inspect(vals)}")

    vv = CastDevice.from_device_records(vals)
    Logger.debug("start: #{inspect(vv)}")


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
