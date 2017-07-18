defmodule ExTus.Utils do
  import Plug.Conn

  def set_base_resp(conn) do
    conn
    |> put_resp_header("Tus-Resumable", ExTus.Config.tus_api_version)
    |> put_resp_header("Cache-Control", "no-store")
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
