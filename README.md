# Extus

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `extus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:extus, "~> 0.1.0"}]
end
```

## 1. Config

```elixir
config :extus,
  storage: ExTus.Storage.Local,
  base_dir: "upload",
  expired_after: 24 * 60 * 60 * 1000, #clean uncompleted upload after 1 day
  clean_interval: 30 * 60 * 1000 # start cleaning job after 30min
```

- `storage`: module which handle storage file application
  Currently, ExTus support `ExTus.Storage.Local` and `ExTus.Storage.S3`
- `base_dir` is where you want to store uploaded file


**Config for S3 uploaded**

```elixir
config :extus,
  storage: ExTus.Storage.S3,
  base_dir: "upload",
	asset_host: "https://dsxymfc8fnnz2.cloudfront.net",

  config :extus, :s3,
    virtual_host: true,
    bucket: "mofiin",
    chunk_size: 5 * 1024 * 1024
```

- `virtual_host`: true if you want to use "https://#{bucket}.s3.amazonaws.com" host.
   default is "https://s3.amazonaws.com/#{bucket}"
- `asset_host`: host which you use to serve uploaded files
- `bucket`: name of s3 bucket
- `chunk_size`: size of part for multipart upload


## 2. Dependencies
If you use S3 to store file, add below dependencies
```elixir
    {:poison, "~> 2.0"},
    {:hackney, "~> 1.6"}
```



## 3. Usage

**Add new controller for upload**

```elixir
defmodule MyApp.UploadController do
  use MyApp.Web, :controller
  use ExTus.Controller

  # start upload file callback
  def on_begin_upload(file_info) do
    IO.inspect "create file: #{inspect file_info}"
  end
	
  # Completed upload file callback
  def on_complete_upload(file_info) do
    IO.inspect "complete file: #{inspect file_info}"
  end
end
```



**Add route**

```elixir
scope "/files", MyApp do
    options "/",  			TusController, :options
    options "/:file",  		TusController, :options
    match :head, "/:file",  TusController, :head
    post "/",  				TusController, :post
    patch "/:file",  		TusController, :patch
    delete "/:file",  		TusController, :delete
end
```



## 4. Implement your own storage

- In progress
   ~You can implement interface `Storage`~
