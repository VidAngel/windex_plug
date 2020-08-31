defmodule WindexPlug do
  import Plug.Conn
  use Plug.Router
  require Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    json_decoder: Jason

  plug Plug.Static, at: "/static", from: {:windex_plug, "/priv/static"}
  use Plug.ErrorHandler

  plug :fetch_query_params
  plug :match
  plug :dispatch, builder_opts()

  def defaults do
    [
      hmac_key: :crypto.strong_rand_bytes(32) |> Base.encode16,
      hmac_ttl: 10*60, # in seconds
      command_module: WindexPlug.CommandList.Default
    ]
  end

  def init(opts \\ []), do: Keyword.merge(defaults(), opts)

  post "/run" do
    command = validate!(conn.body_params["id"], opts[:hmac_ttl], opts[:hmac_key])
    {port, password} = Windex.spawn_server(command)
    send_resp(conn, 200, Jason.encode!(%{port: port, password: password}))
  end

  get "/" do
    form = apply(opts[:command_module], :commands, [])
    |> Enum.map(fn c -> %{id: WindexPlug.hmac(c, opts[:hmac_key]), label: inspect(c)} end)
    |> Jason.encode!
    send_resp(conn, 200, form)
  end

  match "/*_", do: send_resp(conn, 404, "404 - Not Found")

  def hmac(term, key) do
    encoded = term |> :erlang.term_to_binary |> Base.encode16
    creation = DateTime.utc_now |> DateTime.to_unix
    hmac = :crypto.hmac(:sha256, key, "#{encoded}.#{creation}") |> Base.encode16
    "#{encoded}.#{creation}.#{hmac}"
  end

  def validate!(id, ttl, key) do
    [term, creation, hmac] = "#{id}" |> String.split(".")
    now = DateTime.utc_now |> DateTime.to_unix
    creation = creation |> String.to_integer
    true = (now - creation) < ttl
    ^hmac = :crypto.hmac(:sha256, key, "#{term}.#{creation}") |> Base.encode16
    term |> Base.decode16! |> :erlang.binary_to_term
  end

  defp handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
    Logger.error [inspect(kind), ?\s, inspect(reason), ?\s, inspect(stack)]
    send_resp(conn, conn.status, "Something went wrong")
  end

  defmodule CommandList do
    defmacro __using__(_opts) do
      quote do
        def commands, do: [ [run: :observer], [run: "xterm"], ]
        defoverridable commands: 0
      end
    end
  end

  defmodule CommandList.Default, do: use WindexPlug.CommandList
end
