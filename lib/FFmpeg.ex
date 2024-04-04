defmodule FFmpeg do
 @moduledoc """
  Returns ffmpeg command as list of string
  """

  @doc """
  Returns ffmpeg command with arguments for adding watermark
  """
  @spec watermark(String.t(), String.t(), String.t(), map()) :: [String.t()] | []
  def watermark(input, text, output, text_opts \\ []) do
    # add text with white color font and transparency of 0.5
    filter_graph =
      [
        text: "'#{text}'",
        fontsize: text_opts[:fontsize] || 80,
        fontcolor: "white",
        x: text_opts[:x] || 300,
        y: text_opts[:y] || 350,
        alpha: text_opts[:alpha] || 0.5
      ]
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join(":")

    [
      "ffmpeg",
      "-y",
      ["-i", input],
      ["-vf", "drawtext=#{filter_graph}"],
      ~w(-codec:a copy),
      # output should be MP4
      ~w(-f mp4),
      # add flag to fix error while reading the stream
      ~w(-movflags empty_moov),
      # output location
      output
    ]
    |> List.flatten()
  end
end

defmodule FFmpeg.Server do
  @moduledoc """
  HTTP server for demonstrating FFmpeg streaming
  https://hexdocs.pm/plug/readme.html#installation
  """
  alias Plug.RequestId
  use Plug.Router
  require Logger
  require Exile, as: ExCmd
  require RequestId

  plug(Plug.Parsers, parsers: [], pass: ["*/*"])
  plug(:match)
  plug(:dispatch)

  get "/watermark" do
    %{"video_url" => video_url, "text" => text} = conn.params

    cmd = FFmpeg.watermark("pipe:0", text, "-", x: 20, y: 20)
    output_stream = ExCmd.stream!(cmd, input: &Req.get!(video_url, into: &1))

    conn =
      conn
      |> put_resp_content_type("video/mp4")
      |> send_chunked(200)

    Enum.reduce_while(output_stream, conn, fn chunk, conn ->
      case chunk(conn, chunk) do
        {:ok, conn} ->
          Logger.debug("Sent #{IO.iodata_length(chunk)} bytes")
          {:cont, conn}

        {:error, :closed} ->
          Logger.debug("Connection closed")
          {:halt, conn}
      end
    end)
  end

end
