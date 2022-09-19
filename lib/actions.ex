defmodule ExTus.Actions do
  import Plug.Conn
  alias ExTus.Utils
  alias ExTus.UploadInfo
  alias ExTus.UploadCache
  require Logger

  defp storage() do
    Application.get_env(:extus, :storage, ExTus.Storage.Local)
  end

  def options(conn) do
    tus_max_file_size = Application.get_env(:extus, :tus_max_file_size, 536_870_912)

    Logger.info(
      "[TUS][OPTIONS: #{inspect({ExTus.Config.tus_api_version(), ExTus.Config.tus_api_version_supported(), to_string(tus_max_file_size), Enum.join(ExTus.Config.extensions(), ",")})}]"
    )

    conn
    |> handle_preflight_request
    |> put_resp_header("Tus-Resumable", ExTus.Config.tus_api_version())
    |> put_resp_header("Tus-Version", ExTus.Config.tus_api_version_supported())
    |> put_resp_header("Tus-Checksum-Algorithm", "sha1")
    |> put_resp_header("Tus-Max-Size", to_string(tus_max_file_size))
    |> put_resp_header("Tus-Extension", Enum.join(ExTus.Config.extensions(), ","))
    |> resp(200, "")
  end

  def head(conn, identifier) do
    upload_info = UploadCache.get(identifier)

    if is_nil(upload_info) do
      Logger.error("[TUS][HEAD_ERROR: #{inspect(upload_info)}][NOT_FOUND]")

      conn
      |> Utils.set_base_resp()
      |> resp(
        404,
        Jason.encode!(%{
          message: "Not Found",
          details: "[TUS][HEAD_ERROR: Resource not found"
        })
      )
    else
      upload_meta = %{
        size: upload_info.size,
        filename: upload_info.filename
      }

      upload_meta =
        upload_meta
        |> Enum.map(fn {k, v} -> "#{k} #{Base.encode64(to_string(v))}" end)
        |> Enum.join(",")

      Logger.info("[TUS][HEAD: #{inspect(upload_meta)}]")

      if upload_meta not in ["", nil] do
        put_resp_header(conn, "Upload-Metadata", upload_meta)
      else
        conn
      end
      |> Utils.set_base_resp()
      |> Utils.put_cors_headers()
      |> put_resp_header("Upload-Offset", "#{upload_info.offset}")
      |> put_resp_header("Upload-Length", "#{upload_info.size}")
      |> resp(200, "Tus Head, returned upload_info: #{inspect(identifier)}")
    end
  end

  def patch(conn, identifier, complete_cb) do
    headers = Utils.read_headers(conn)
    {offset, _} = Integer.parse(headers["upload-offset"])
    upload_info = UploadCache.get(identifier)

    if is_nil(upload_info) do
      Logger.error("[TUS][PATCH_ERROR: #{inspect(upload_info)}][NOT_FOUND]")
      conn
      |> Utils.set_base_resp()
      |> resp(
        404,
        Jason.encode!(%{
          message: "Not Found",
          details: "[TUS][PATCH_ERROR: Resource not found}]"
        })
      )
    else
      [alg, checksum] = String.split(headers["upload-checksum"] || "_ _")

      if headers["upload-checksum"] not in [nil, ""] and alg not in ExTus.Config.hash_algorithms() do
        Logger.error(
          "[TUS][UPLOAD_OFFSET_ERROR: Upload Checksum Null][HEADERS: #{inspect(headers)}]"
        )

        conn
        |> Utils.set_base_resp()
        |> resp(
          400,
          Jason.encode!(%{
            message: "Bad Request",
            details:
              "[TUS][UPLOAD_OFFSET_ERROR: Upload Checksum Null][HEADERS: #{inspect(headers)}]"
          })
        )
      else
        # %{size: current_offset} = File.stat!(file_path)
        if offset != upload_info.offset do
          Logger.error("[TUS][UPLOAD_OFFSET_ERROR: #{inspect({offset, upload_info})}]")

          conn
          |> Utils.set_base_resp()
          |> resp(
            409,
            Jason.encode!(%{
              message: "Conflict",
              details: "[TUS][UPLOAD_OFFSET_ERROR: #{inspect({offset, upload_info})}]"
            })
          )
        else
          # read data Max chunk size is 8MB, if transferred data > 8MB, ignore it
          case read_body(conn) do
            {_, binary, conn} ->
              data_length = byte_size(binary)
              upload_info = Map.put(upload_info, :offset, data_length + upload_info.offset)

              # check Checksum if received a checksum digest
              if alg in ExTus.Config.hash_algorithms() do
                alg = if alg == "sha1", do: "sha", else: alg

                hash_val =
                  :crypto.hash(String.to_atom(alg), binary)
                  |> Base.encode32()

                if checksum != hash_val do
                  Logger.error("[TUS][PATCH_CHECKSUM_ERROR: #{inspect({checksum, hash_val})}]")

                  conn
                  |> Utils.set_base_resp()
                  |> resp(
                    460,
                    Jason.encode!(%{
                      message: "Checksum Mismatch",
                      details: "[TUS][PATCH_CHECKSUM_ERROR: #{inspect({checksum, hash_val})}]"
                    })
                  )
                else
                  write_append_data(conn, upload_info, binary, complete_cb)
                end
              else
                write_append_data(conn, upload_info, binary, complete_cb)
              end

            {:error, term} ->
              error_str = inspect({upload_info, term})
              Logger.error("[TUS][PATCH_ERROR: #{error_str}]")

              conn
              |> Utils.set_base_resp()
              |> resp(
                500,
                Jason.encode!(%{
                  message: "Server Error",
                  details: "[TUS][PATCH_ERROR: Unable to patch]"
                })
              )
          end
        end
      end
    end
  end

  defp write_append_data(conn, upload_info, binary, complete_cb) do
    storage().append_data(upload_info, binary)
    |> case do
      {:ok, upload_info} ->
        UploadCache.update(upload_info)

        Logger.info("[TUS][WRITE_APPEND_DATA: INFO: #{inspect(upload_info)}]")

        url =
          if upload_info.offset >= upload_info.size do
            rs = storage().complete_file(upload_info)

            # if upload fail remove uploaded file
            with {:error, err} <- rs do
              Logger.warn("[TUS][WRITE_APPEND_COMPLETION_ERROR: #{inspect({upload_info, err})}]")
              storage().abort_upload(upload_info)
            end

            # remove cache info
            UploadCache.delete(upload_info.identifier)

            if not is_nil(complete_cb) do
              complete_cb.(upload_info, conn.req_headers)
            else
              ""
            end
          else
            ""
          end

        # Last time I tried to put file delete, video upload of iOS files had not complete and we saw corrupt files in S3.
        # Need find create way for s3 completion
        # storage().delete(upload_info)

        conn
        |> Utils.set_base_resp()
        |> Utils.put_cors_headers()
        |> put_resp_header("Upload-Offset", "#{upload_info.offset}")
        |> put_resp_header("URL", "#{url}")
        |> resp(204, "")

      {:error, err} ->
        error_str = inspect({upload_info, err})
        Logger.error("[TUS][WRITE_APPEND_ERROR: #{error_str}]")

        conn
        |> Utils.set_base_resp()
        |> resp(
          404,
          Jason.encode!(%{
            message: "Not Found",
            details: "[TUS][PATCH_ERROR]: Resource not found"
          })
        )
    end
  end

  def post(conn, create_cb) do
    headers = Utils.read_headers(conn)

    # Identify path for Profile Image
    upload_type = if conn.request_path == "/profile-image" do
      "PROFILE_IMAGE"
    else
      headers["upload-type"]
    end
    meta = Utils.parse_meta_data(headers["upload-metadata"])
    {upload_length, _} = Integer.parse(headers["upload-length"])

    if upload_length > Application.get_env(:extus, :tus_max_file_size, 536_870_912) do
      conn
      |> resp(
        413,
        Jason.encode!(%{
          message: "Tus Max File Size Exceeded",
          details: "[TUS][UPLOAD_ERROR: Max File Size Exceeded: #{upload_length}]"
        })
      )
    else
      file_name =
        (meta["filename"] || "")
        |> Base.decode64!()

      file_ext = String.split(file_name, ".") |> List.last() |> String.downcase()

      allowed_file_extension =
        Application.get_env(:extus, :allowed_file_extension, [
          "jpg",
          "jpeg",
          "png",
          "mpg",
          "mp2",
          "mp3",
          "mpeg",
          "mpe",
          "mpv",
          "mp4",
          "m4p",
          "m4v",
          "ogg",
          "avi",
          "wmv",
          "mov",
          "qt",
          "flv",
          "swf",
          "opus"
        ])

      allowed = Enum.member?(allowed_file_extension, file_ext)

      if allowed do
        {:ok, {identifier, filename}} = storage().initiate_file(file_name)

        user_id =
          conn.assigns[:user_id] || Kernel.inspect(Enum.random(1000_000_000..1000_000_000_000))

        info = %UploadInfo{
          identifier: identifier,
          filename: filename,
          size: upload_length,
          started_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          options: %{"user_id" => user_id}
        }

        UploadCache.put(info)

        if create_cb do
          create_cb.(info, conn.req_headers)
        end

        location = get_upload_location(conn, upload_type, identifier)

        conn
        |> put_resp_header("Tus-Resumable", ExTus.Config.tus_api_version())
        |> put_resp_header("Location", location)
        |> Utils.put_cors_headers()
        |> resp(201, "")
      else
        conn
        |> resp(
          415,
          Jason.encode!(%{
            message: "Unsupported media type",
            details: "[TUS][UNSUPPORTED_FILETYPE_ERROR: invalid filetype: #{file_ext}]"
          })
        )
      end
    end
  end

  def delete(conn, identifier) do
    upload_info = UploadCache.get(identifier)

    if is_nil(upload_info) do
      conn
      |> Utils.set_base_resp()
      |> resp(
        404,
        Jason.encode!(%{
          message: "Not Found",
          details: "[TUS][DELETE_ERROR: Resource not found}]"
        })
      )
    else
      case storage().delete(upload_info) do
        :ok ->
          conn
          |> Utils.set_base_resp()
          |> Utils.put_cors_headers()
          |> resp(204, "No Content")

        _ ->
          conn
          |> Utils.set_base_resp()
          |> resp(
            500,
            Jason.encode!(%{
              message: "Server Error",
              details: "[TUS][DELETE_ERROR: Unable to delete]"
            })
          )
      end
    end
  end

  def handle_preflight_request(conn) do
    headers = Enum.into(conn.req_headers, Map.new())

    if headers["access-control-request-method"] do
      conn
      |> put_resp_header(
        "Access-Control-Allow-Methods",
        "POST, GET, HEAD, PATCH, DELETE, OPTIONS"
      )
      |> put_resp_header(
        "Access-Control-Allow-Headers",
        "Origin, X-Requested-With, Content-Type, Upload-Length, Upload-Offset, Tus-Resumable, Upload-Metadata"
      )
      |> put_resp_header("Access-Control-Max-Age", "86400")
    else
      conn
    end
  end

  def get_upload_location(conn, upload_type, identifier) do
    base_url =
      case Application.get_env(:extus, :environment) do
        :prod ->
          scheme = :https
          "#{scheme}://#{conn.host}"

        _ ->
          scheme = :https
          "#{scheme}://#{conn.host}"
      end

    Logger.info(
      "[TUS][POST][GET_UPLOAD_LOCATION][UPLOAD_TYPE: #{inspect(upload_type)}][IDENTIFIER: #{inspect(identifier)}][ENV: #{inspect(Application.get_env(:extus, :environment))}][BASE_URL: #{inspect(base_url)}]"
    )

    base_url
    |> URI.merge(
      Path.join(
        case upload_type do
          "VIDEO_ANSWER" -> ExTus.Config.video_upload_url()
          "PROFILE_IMAGE" -> ExTus.Config.profile_image_url()
          _ -> ExTus.Config.upload_url()
        end,
        identifier
      )
    )
    |> to_string
  end
end
