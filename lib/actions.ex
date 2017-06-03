defmodule ExTus.Actions do
  defmacro __using__(_opts) do

    # generate function for http verb that tus support
    [:options, :head, :patch, :post, :delete]
    |> Enum.map(fn name ->
      quote bind_quoted: [name: name] do
        def unquote(name)(conn) do
          ExTus.Actions.process_request(__MODULE__, unquote(name), conn)
        end
      end
    end)
  end

  def process_request(mod, method, conn) do
    extensions = ["core"] ++ ExTus.Config.extensions
    process_extension(mod, extensions, method, conn)
    |> Plug.Conn.send_resp
  end

  @doc """
  For each function, call handler to process the request
  """
  defp process_extension(mod, [ext|tail], method, conn) do
    case ExTus.Extensions.handle(ext, method, conn) do
      {:ok, conn} ->
        process_extension(mod, tail, method, conn)
      {:stop, conn} ->
        conn
    end
  end

  defp process_extension(_mod, nil , method, conn), do: conn
  defp process_extension(_mod, [] , method, conn), do: conn
end
