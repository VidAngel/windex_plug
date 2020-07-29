defmodule WindexPlug do
  use Plug.Router
  import Plug.Conn

  def defaults do
    [
      hmac_key: :crypto.strong_rand_bytes(32) |> Base.encode16,
      hmac_ttl: 10*60, # in seconds
      command_module: CommandList.Default
    ]
  end

  def init(opts \\ []), do: Keyword.merge(defaults(), opts)

  forward "/novnc", to: Plug.Static, init_opts: [at: "*", from: {:plug_windex, "priv/novnc"}]

  post "/run" do
    form = %{}
    command = validate!(form['id'], opts[:hmac_ttl], opts[:hmac_key])
    {port, password} = Windex.spawn_server(command)
    send_resp(conn, 200, password)
  end

  match _, do: send_resp(conn, 404, "oops")

  defp hmac(term, key) do
    encoded = term |> :erlang.term_to_binary |> Base.encode16
    creation = DateTime.utc_now |> DateTime.to_unix
    hmac = :crypto.hmac(:sha256, key, "#{encoded}.#{creation}") |> Base.encode16
    "#{encoded}.#{creation}.#{hmac}"
  end

  defp validate!(id, ttl, key) do
    [term, creation, hmac] = "#{id}" |> String.split(".")
    now = DateTime.utc_now |> DateTime.to_unix
    creation = creation |> String.to_integer
    true = (now - creation) < ttl
    ^hmac = :crypto.hmac(:sha256, key, "#{term}.#{creation}") |> Base.encode16
    term |> Base.decode16! |> :erlang.binary_to_term
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
