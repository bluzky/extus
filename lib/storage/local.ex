defmodule ExTus.Storage.Local do
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

    File.mkdir_p!(Path.join(base_dir(), dir))
    file_path = Path.join(dir, filename)

    full_path(file_path)
    |> File.open!([:write])
    |> File.close

    identifier = :crypto.hash(:sha256, filename) |> Base.encode16
    {:ok, {identifier, file_path}}
  end

  def put_file(%{filename: _file_path}, _destination) do

  end

  def append_data(%{filename: file_path} = info, data) do
    full_path(file_path)
    |> File.open([:append, :binary, :delayed_write, :raw])
    |> case do
      {:ok, file} ->
        IO.binwrite(file, data)
        File.close(file)
        {:ok, info}
      {:error, err} ->
        {:error, err}
       _ -> {:error, :unknown}
    end
  end

  def complete_file(%{filename: _file_path}) do
    {:ok, nil}
  end

  def abort_upload(%{filename: file}) do
    full_path(file)
    |> File.rm
  end

  def url(_file) do
		
  end

  def delete(%{filename: file_path}) do
    full_path(file_path)
    |> File.rm
  end

	defp base_dir, do: Application.get_env(:extus, :base_dir, "upload")
	
  defp full_path(file_path) do
    Path.join(base_dir(), file_path)
  end
end
