defmodule Air2Cast do
  @moduledoc """
  Documentation for `Air2Cast`.
  """
  @shairport_sync "shairport-sync"

  defstruct config: nil
  # @ffmpeg
  @doc """
  Hello world.

  ## Examples

      iex> Air2Cast.hello()
      :world

  """
  def hello do
    :world
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
