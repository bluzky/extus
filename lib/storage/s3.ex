defmodule ExTus.Storage.S3 do
  use ExTus.Storage

  def storage_dir() do
    time = DateTime.utc_now
    "#{time.year}/#{time.month}/#{time.day}"
  end

  def filename(file_name) do
     base_name = Path.basename(file_name, Path.extname(file_name))
     timestamp = DateTime.utc_now |> DateTime.to_unix
     "#{base_name}_#{timestamp}#{Path.extname(file_name)}"
  end

  def initiate_file(file_name) do
    dir = storage_dir()
    filename = filename(file_name)
    file_path = Path.join([base_dir(), dir, filename])


    %{bucket: "", path: file_path, opts: [], upload_id: nil}
    |> ExAws.S3.Upload.initialize([host: endpoint(bucket())])
    |> case do
      {:ok, rs} -> {:ok, {rs.upload_id, file_path}}
      err -> err
    end
  end

  def put_file(%{filename: _file_path}, _destination) do

  end

  def append_data(%{identifier: upload_id, filename: file, options: options} = info, data) do
    part_id =  (options[:current_part] || 0) + 1 #div(info.offset, 5 * 1024 * 1024) + 1 # 5MB each part

    ""
    |> ExAws.S3.upload_part(file, upload_id, part_id, data, ["Content-Length": byte_size(data)])
    |> ExAws.request([host: endpoint(bucket())])
    |> case do
      {:ok, response} ->
        %{headers: headers} = response
        {_, etag} = Enum.find(headers, fn {k, _v} ->
          String.downcase(k) == "etag"
        end)
        parts = options[:parts] || []
        parts = parts ++ [{part_id, etag}]

        info = %{info | options: %{parts: parts, current_part: part_id}}

        {:ok, info}
      err -> err
    end
  end

  def complete_file(%{filename: file, identifier: upload_id, options: options}) do
    parts = options[:parts] || []

    ""
    |> ExAws.S3.complete_multipart_upload(
        file, upload_id,
        Enum.sort_by(parts, &elem(&1, 0))
    )
    |> ExAws.request([host: endpoint(bucket())])
  end

  def url(file) do
    Path.join asset_host(), file
  end

  def abort_upload(%{identifier: upload_id, filename: file}) do
    ""
    |> ExAws.S3.abort_multipart_upload(file, upload_id)
    |> ExAws.request([host: endpoint(bucket())])
  end

  def delete(file) do
    ""
    |> ExAws.S3.delete_object(file)
    |> ExAws.request([host: endpoint(bucket())])
  end

  defp base_dir() do
   Application.get_env(:extus, :base_dir)
  end

  defp chunk_size do
    Application.get_env(:extus, :s3, [])
    |> Keyword.get(:chunk_size, 5 * 1024 * 1024)
  end

  defp bucket do
    Application.get_env(:extus, :s3, [])
    |> Keyword.get(:bucket)
  end

  defp virtual_host() do
    s3_conf = Application.get_env(:extus, :s3, [])
    s3_conf[:virtual_host] || false
  end

  defp endpoint(bucket) do
    "#{bucket}.s3.amazonaws.com"
  end

  defp host(bucket) do
    case virtual_host() do
      true -> "https://#{bucket}.s3.amazonaws.com"
      _    -> "https://s3.amazonaws.com/#{bucket}"
    end
  end

  defp asset_host do
    Application.get_env(:extus, :asset_host, host(bucket()))
  end
end
