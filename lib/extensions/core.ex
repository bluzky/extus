defmodule ExTus.Extensions.Core do
  import Plug.Conn
  alias ExTus.Utils

  defmacro __using__(_) do
    quote do
      def handle("core", method, conn) when method in [:options, :head, :patch] do
        apply(ExTus.Extensions.Core, method, [__MODULE__, conn])
      end

      def handle("core", _, conn) do
         {:ok, conn}
      end
    end
  end

  def options(definition, conn)do
    conn = conn
    |> handle_preflight_request
    |> put_resp_header("Tus-Resumable", ExTus.Config.tus_api_version)
    |> put_resp_header("Tus-Version", ExTus.Config.tus_api_version_supported)
    |> put_resp_header("Tus-Checksum-Algorithm", "sha1")
    |> put_resp_header("Tus-Max-Size", to_string(ExTus.Config.tus_max_file_size))
    |> put_resp_header("Tus-Extension", Enum.join(ExTus.Config.extensions, ","))
    |> resp(200, "")
    |> Utils.ok
  end

  def head(definition, conn)do
    file_name = get_file_name(conn.path_info)
    file_path = ExTus.Utils.get_file_path(file_name)

    if not File.exists?(file_path) do
      conn
      |> Utils.set_base_resp
      |> resp(404, "")
      |> Utils.stop

    else
      %{size: file_size} = File.stat!(file_path)
      # read info for uploading file
      upload_info = Utils.read_chunk_info(file_name)
      upload_meta = upload_info
        |> Enum.map(fn{k, v} ->  "#{k} #{Base.encode64(v)}" end)
        |> Enum.join(",")

      if not upload_meta in ["", nil] do
        put_resp_header(conn, "Upload-Metadata", upload_meta)
      else
        conn
      end
      |> Utils.set_base_resp
      |> Utils.put_cors_headers
      |> put_resp_header("Upload-Offset", "#{file_size}")
      |> put_resp_header("Upload-Length", "#{Map.get(upload_info, "size")}")
      |> resp(200, "")
      |> Utils.ok
    end
  end

  def patch(definition, conn)do
    headers = Utils.read_headers(conn)
    {offset, _} = Integer.parse(headers["upload-offset"])

    file = get_file_name(conn.path_info)
    file_path = ExTus.Utils.get_file_path(file)

    if not File.exists?(file_path) do
      conn
      |> Utils.set_base_resp
      |> resp(404, "")
      |> Utils.stop

    else
      %{size: current_offset} = File.stat!(file_path)

      if  current_offset != offset do
        conn
        |> Utils.set_base_resp
        |> resp(409, "")
        |> Utils.stop

      else
        # append data
        case append_file_data(conn, file) do
          :error ->
            conn
            |> Utils.set_base_resp
            |> Utils.put_cors_headers
            |> put_resp_header("Upload-Offset", "#{offset}")
            |> resp(503, "")
            |> Utils.stop

          {:ok, conn, data_length} ->
            conn
            |> Utils.set_base_resp
            |> Utils.put_cors_headers
            |> put_resp_header("Upload-Offset", "#{offset + data_length}")
            |> resp(204, "")
            |> Utils.ok
        end
      end
    end
  end

  defp append_file_data(conn, filename) do
    path = Utils.get_file_path(filename)
    case File.open(path, [:append, :binary, :delayed_write, :raw]) do
      {:ok, file} ->
        rs = write_chunk_data(conn, file)
        File.close(file)
        rs
      {:error, err} ->
        :error
    end
  end

  defp write_chunk_data(conn, file, data_length \\ 0) do
    case read_body(conn) do
      {:ok, binary, conn} ->
        IO.binwrite(file, binary)
        {:ok, conn, data_length + byte_size(binary)}

      {:more, binary, conn} ->
        IO.binwrite(file, binary)
        write_chunk_data(conn, file, data_length + byte_size(binary))

      {:error, term} ->
        :error
    end
  end


  defp get_file_name(request_path) do
    [file_name, endpoint] = request_path
                            |> Enum.reverse
                            |> Enum.take(2)
    file_name
  end

  def handle_preflight_request(conn) do
    headers = Enum.into(conn.req_headers, Map.new)
    if headers["access-control-request-method"] do
      conn
      |> put_resp_header("Access-Control-Allow-Methods", "POST, GET, HEAD, PATCH, DELETE, OPTIONS")
      |> put_resp_header("Access-Control-Allow-Origin", "null")
      |> put_resp_header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Upload-Length, Upload-Offset, Tus-Resumable, Upload-Metadata")
      |> put_resp_header("Access-Control-Max-Age", "86400")
    else
      conn
    end
  end
end
