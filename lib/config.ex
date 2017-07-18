defmodule ExTus.Config do
  # this is some hard code config, it will be configurable
  @upload_url  "/files"
  @upload_folder  "./uploads/"
  @tus_api_version  "1.0.0"
  @tus_api_version_supported  "1.0.0"
  @tus_max_file_size  4294967296 # 4GByte
  @file_overwrite  true
  @upload_finish_cb  nil
  @upload_file_handler_cb  nil
  @extensions [
        "creation",
        #"expiration",
        "termination",
        "checksum",
        #{}"creation-defer-length",
        # "checksum-trailer",          # todo
        #{}"concatenation",
        # "concatenation-unfinished",  # todo
    ]

  @hash_algorithms ["sha1", "md5"]

  def upload_url, do: @upload_url
  def upload_folder, do: @upload_folder
  def tus_api_version, do: @tus_api_version
  def tus_api_version_supported, do: @tus_api_version_supported
  def tus_max_file_size, do: @tus_max_file_size
  def file_overwrite, do: @file_overwrite
  def upload_finish_cb, do: @upload_finish_cb
  def upload_file_handler_cb, do: @upload_file_handler_cb
  def extensions, do: @extensions
  def hash_algorithms, do: @hash_algorithms
end
