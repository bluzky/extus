defmodule ExTus.Utils do
  import Plug.Conn

  def set_base_resp(conn) do
    conn
    |> put_resp_header("Tus-Resumable", ExTus.Config.tus_api_version)
    |> put_resp_header("Cache-Control", "no-store")
  end

  def write_chunk_info(file, info = %{}) do
    path = get_file_path(file)
    info_file = path <> ".ci"
    file = File.open!(info_file, [:write])

    data = info
      |> Enum.map(fn{k, v} ->
        "#{k}=#{v}"
      end)
      |> Enum.join("\n")

    IO.write(file, data)
    File.close(file)
  end

  def read_chunk_info(file) do
    path = get_file_path(file)
    info_file = path <> ".ci"

    # read info file content into an map
    file = File.open!(info_file, [:read])
    info = file
      |> IO.stream(:line)
      |> Enum.map(fn line ->
          line
          |> String.replace(~r/[\r\n]/, "")
          |> String.split("=", parts: 2)
          |> List.to_tuple
        end)
      |> Enum.into(Map.new)
    File.close(file)
    info
  end

  def remove_chunk_info(file) do
    path = get_file_path(file)
    info_file = path <> ".ci"
    File.rm! info_file
  end


  def get_file_path(file)do
    Path.join([ExTus.Config.upload_folder, file])
    |> Path.absname
  end

  def read_headers(conn) do
    conn.req_headers
    |> Enum.map(fn {k, v} -> {String.downcase(k), v} end)
    |> Enum.into(Map.new)
  end

  def parse_meta_data(meta_str) do
    meta_str
    |> String.split(",")
    |> Enum.map(fn item ->
      String.split(item, " ", parts: 2)
      |> List.to_tuple
    end)
    |> Enum.into(Map.new)
  end

  def put_cors_headers(conn) do
    conn
    |> put_resp_header("Access-Control-Allow-Origin", "null")
    |> put_resp_header("Access-Control-Expose-Headers", "Upload-Offset, Location, Upload-Length, Tus-Version, Tus-Resumable, Tus-Max-Size, Tus-Extension, Upload-Metadata")
  end
end
