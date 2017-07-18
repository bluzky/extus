# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :extus,
  storage: ExTus.Storage.Local,
  base_dir: "upload",
  expired_after: 24 * 60 * 60 * 1000, #clean uncompleted upload after 1 day
  clean_interval: 30 * 60 * 1000 # start cleaning job after 30min

# config :extus,
#   base_dir: "dev",
#   storage: ExTus.Storage.S3

config :extus, :s3,
  asset_host: "https://dsxymfc8fnnz2.cloudfront.net",
  bucket: "mofiin",
  virtual_host: true,
  chunk_size: 5 * 1024 * 1024 * 1000

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :extus, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:extus, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
