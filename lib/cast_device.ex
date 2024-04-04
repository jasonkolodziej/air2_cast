defmodule CastDevice do
  @moduledoc """
  Documentation for `Air2Cast`.
  """
  require Mdns.Client, as: Client
  require Mdns.EventManager, as: OnEvent
  @cast "_googlecast._tcp.local"

  defstruct controller: nil, hw_address: nil
  @spec find_devices() :: any()
  @doc """
  Hello world.

  ## Examples

      iex> Air2Cast.hello()
      :world

  """
  def find_devices() do
    Client.start()
    #? allows for the registration of a callback
    OnEvent.register()
    Client.query(
      @cast
    )
    # ? Returns a list of devices
    Client.devices()
  end


end
