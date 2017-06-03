defmodule ExTus.Extensions.Creation do
  import Plug.Conn

  defmacro __using__(_) do
    quote do
      def handle("creation", :post, conn) do
        ExTus.Extensions.Creation.post(__MODULE__, conn)
      end

      def handle("creation", _, conn) do
         {:ok, conn}
      end
    end
  end

  def post(definition, conn)do
     headers = ExTus.Utils.read_headers(conn)

     meta = ExTus.Utils.parse_meta_data(headers["upload-metadata"])
     {upload_length, _} = Integer.parse(headers["upload-length"])

     if upload_length > ExTus.Config.tus_max_file_size do
       conn
       |> resp(413, "")
       |> ExTus.Utils.stop
     else
       file_name = (meta["filename"] || "")
          |> hash_file_name_with_time

       info = %{
         filename: meta["filename"] || "",
         size: upload_length
       }

       init_upload_file(file_name)
       ExTus.Utils.write_chunk_info(file_name, info)

       location = ("#{conn.scheme}://#{conn.host }:#{conn.port}")
          |> URI.merge(Path.join(ExTus.Config.upload_url, file_name))
          |> to_string
       conn
       |> put_resp_header("Tus-Resumable", ExTus.Config.tus_api_version)
       |> put_resp_header("Location", location)
       |> ExTus.Utils.put_cors_headers
       |> resp(201, "")
       |> ExTus.Utils.stop
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
    ExTus.Utils.get_file_path(file)
    |> File.open!([:write])
    |> File.close
  end
end
