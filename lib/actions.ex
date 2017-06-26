defmodule ExTus.Actions do
  import Plug.Conn
  alias ExTus.Utils


  def options(conn)do
    conn = conn
    |> handle_preflight_request
    |> put_resp_header("Tus-Resumable", ExTus.Config.tus_api_version)
    |> put_resp_header("Tus-Version", ExTus.Config.tus_api_version_supported)
    |> put_resp_header("Tus-Checksum-Algorithm", "sha1")
    |> put_resp_header("Tus-Max-Size", to_string(ExTus.Config.tus_max_file_size))
    |> put_resp_header("Tus-Extension", Enum.join(ExTus.Config.extensions, ","))
    |> resp(200, "")
  end

  def head(conn, file_name)do
    file_path = Utils.get_file_path(file_name)

    if not File.exists?(file_path) do
      conn
      |> Utils.set_base_resp
      |> resp(404, "")

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
    end
  end

  def patch(conn, file_name, complete_cb)do
    headers = Utils.read_headers(conn)
    {offset, _} = Integer.parse(headers["upload-offset"])
    file_path = Utils.get_file_path(file_name)

    if not File.exists?(file_path) do
      conn
      |> Utils.set_base_resp
      |> resp(404, "")

    else
      [alg, checksum] = String.split(headers["upload-checksum"] || "_ _")
      if not is_nil(headers["upload-checksum"]) and not alg in ExTus.Config.hash_algorithms do
        conn
        |> Utils.set_base_resp
        |> resp(400, "Bad Request")
      else

        %{size: current_offset} = File.stat!(file_path)
        if  current_offset != offset do
          conn
          |> Utils.set_base_resp
          |> resp(409, "Conflict")
        else
          upload_info = Utils.read_chunk_info(file_name)
          #read data Max chunk size is 8MB, if transferred data > 8MB, ignore it
          case read_body(conn) do
            {_, binary, conn} ->
              data_length = byte_size(binary)

              if alg in ExTus.Config.hash_algorithms do
                alg = if alg == "sha1", do: "sha", else: alg
                hash_val = :crypto.hash(String.to_atom(alg), binary)
                  |> Base.encode32()

                if checksum != hash_val do
                  conn
                  |> Utils.set_base_resp
                  |> resp(460, "Checksum Mismatch")
                else
                  append_file_data(file_name, binary)
                  if (current_offset + data_length) >= String.to_integer(upload_info["size"])
                   and not is_nil(complete_cb)
                  do
                    complete_cb.(Utils.get_file_path(file_name))
                  end

                  conn
                  |> Utils.set_base_resp
                  |> Utils.put_cors_headers
                  |> put_resp_header("Upload-Offset", "#{current_offset + data_length}")
                  |> resp(204, "")
                end
              else
                append_file_data(file_name, binary)
                if current_offset + data_length >= String.to_integer(upload_info["size"])
                  and not is_nil(complete_cb)
                do
                  complete_cb.(Utils.get_file_path(file_name))
                end

                conn
                |> Utils.set_base_resp
                |> Utils.put_cors_headers
                |> put_resp_header("Upload-Offset", "#{current_offset + data_length}")
                |> resp(204, "")
              end
            {:error, term} ->
              conn
              |> Utils.set_base_resp
              |> resp(500, "Server error")
          end
        end

      end
    end
  end

  def post(conn, create_cb)do
     headers = Utils.read_headers(conn)

     meta = Utils.parse_meta_data(headers["upload-metadata"])
     {upload_length, _} = Integer.parse(headers["upload-length"])

     if upload_length > ExTus.Config.tus_max_file_size do
       conn
       |> resp(413, "")
     else
       file_name = (meta["filename"] || "")
          |> hash_file_name_with_time

       info = %{
         filename: meta["filename"] || "",
         size: upload_length
       }

       init_upload_file(file_name)
       Utils.write_chunk_info(file_name, info)

       if create_cb do
         info
         |> Map.put(:path, Utils.get_file_path(file_name))
         |> create_cb.()
       end

       location = ("#{conn.scheme}://#{conn.host }:#{conn.port}")
          |> URI.merge(Path.join(ExTus.Config.upload_url, file_name))
          |> to_string
       conn
       |> put_resp_header("Tus-Resumable", ExTus.Config.tus_api_version)
       |> put_resp_header("Location", location)
       |> Utils.put_cors_headers
       |> resp(201, "")
     end
  end


  def delete(conn, file_name) do
    file_path = Utils.get_file_path(file_name)

    if not File.exists?(file_path) do
      conn
      |> Utils.set_base_resp
      |> resp(404, "Not Found")
    else
      case File.rm(file_path) do
        :ok ->
          conn
          |> Utils.set_base_resp
          |> Utils.put_cors_headers
          |> resp(204, "No Content")
        _ ->
          conn
          |> Utils.set_base_resp
          |> resp(500, "Server Error")
      end
    end
  end

  defp hash_file_name_with_time(name) do
    time_str = DateTime.utc_now
      |> DateTime.to_unix()
      |> to_string

      :crypto.hash(:sha, time_str <> name)
      |> Base.encode32
      |> String.downcase
  end

  defp init_upload_file(file) do
    Utils.get_file_path(file)
    |> File.open!([:write])
    |> File.close
  end



  defp append_file_data(filename, data) do
    path = Utils.get_file_path(filename)

    case File.open(path, [:append, :binary, :delayed_write, :raw]) do
      {:ok, file} ->
        IO.binwrite(file, data)
        File.close(file)
      {:error, err} ->
        :error
    end
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
