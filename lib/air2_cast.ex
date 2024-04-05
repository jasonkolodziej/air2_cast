defmodule Air2Cast do
  @moduledoc """
  Documentation for `Air2Cast`.
  """
alias Air2Cast.Transcoder


  defstruct config: nil
  # @ffmpeg
  @doc """
  Hello world.

  ## Examples

      iex> Air2Cast.hello()
      :world

  """
  def hello do

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
