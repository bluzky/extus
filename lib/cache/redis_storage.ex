defmodule Extus.Cache.RedisStorage do
	@storage_name :upload_cache
	
	def init() do
		config = 
			(Application.get_env(:extus, :redis) || [])
		
		Redix.start_link(config)
	end
	
	def put(conn, key, data) do
		Redix.command(conn, ["HSET", @storage_name, key, Poison.encode!(data)])
		|> case do
			{:ok, info} -> info
			_ -> nil
		end
	end
	
	def get(conn, key) do
		Redix.command(conn, ["HGET", @storage_name, key])
		|> case do
			{:ok, info} -> parse_data(info)
			_ -> nil
		end
	end
	
	def update(conn, key, data) do
		Redix.command(conn, ["HSET", @storage_name, key, Poison.encode!(data)])
	end
	
	def del(conn, key) do
		Redix.command(conn, ["HDEL", @storage_name, key])
	end
	
	def all(conn) do
		Redix.command(conn, ["HVALS", @storage_name])
		|> case do
			{:ok, data} -> Enum.map(data, &parse_data/1)
			_ -> nil
		end
	end
	
	defp parse_data(nil) do
		nil
	end
	
	defp parse_data(data)do
		Poison.decode(data)
		|> case do
			{:ok, json} -> parse_value(json)
			err -> nil
		end
	end
	
	defp parse_value(data) when is_map(data) do
		data	
		|> Enum.map(fn {k, v} -> {String.to_atom(k), parse_value(v)} end)
		|> Enum.into(Map.new)
	end
	
	defp parse_value(data), do: data
end