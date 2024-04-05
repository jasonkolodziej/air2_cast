defmodule CastDevice do
  @moduledoc """
  Documentation for `Air2Cast`.
  """


  @type mac_address :: Mac.t()

  defstruct controller: nil, hw_address: :mac_address



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
end
