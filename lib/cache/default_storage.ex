defmodule Extus.Cache.DefaultStorage do
	@storage_name :upload_cache
	
	def init() do
		PersistentEts.new(@storage_name, "upload_cache.tab", [:named_table, :set, :public])
		{:ok, nil}
	end
	
	def put(_, key, data) do
		:ets.insert_new(@storage_name, {key, data})
	end
	
	def get(_, key) do
		:ets.lookup(@storage_name, key)
		|> List.first()
		|> Kernel.||({nil, nil})
		|> elem(1)
	end
	
	def update(_, key, data) do
		:ets.insert(@storage_name, {key, data})
	end
	
	def del(_, key) do
		:ets.delete(@storage_name, key)
	end
	
	def all(_) do
		:ets.tab2list(@storage_name)
		|> Enum.map(fn x -> elem(x, 1) end)
	end
end