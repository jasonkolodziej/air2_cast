defmodule Air2Cast do
  @moduledoc """
  Documentation for `Air2Cast`.
  """
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
  def start(_type, _args) do
    IO.puts "starting"
    # d = %CastDevice{ip_address: , mac_address: nil}
    CastDevice.from_ip_address!(IP.from_string!("192.168.1.193")) |> IO.puts
    # IO.puts(all[0])

      #     [IPaddr, _HWType, _Flags, MAC | _] ->
      #       List.to_tuple([
      #         List.to_integer(E, 16)
      #       || E <- &String.split(
      #         &1, ":")
      #       ]);
      #       _ -> arp_lookup_iter(fh, IPaddr)

    #IP.from_string!("192.168.1.193") |> :procket. |> IO.puts
  #  :inet_ext.parse_address("192.168.1.193") |> :inet_ext.route |> IO.puts
    # some more stuff
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
