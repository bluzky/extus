defmodule ExTus.UploadInfo do
  defstruct [identifier: "", filename: "", offset: 0, size: 0, started_at: nil, options: %{}]
end

defmodule ExTus.UploadCache do
  use GenServer

  # Client

 def start_link() do
  #  table = :ets.new(:upload_cache, [:named_table, :set, :protected])
   PersistentEts.new(:upload_cache, "upload_cache.tab", [:named_table, :set, :public])
   GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
 end

 def put(item) do
   GenServer.call(__MODULE__, {:put, item})
 end

 def get(key) do
   GenServer.call(__MODULE__, {:get, key})
 end

 def update(item) do
   GenServer.cast(__MODULE__, {:update, item})
 end

 def delete(key) do
   GenServer.cast(__MODULE__, {:delete, key})
 end

 # Server (callbacks)

 def handle_call({:put, item}, _from, state) do
   item = Map.delete(item, :__struct__)
   rs = :ets.insert_new(:upload_cache, {item.identifier, item})
   {:reply, rs, state}
 end

 def handle_call({:get, key}, _from, state) do
   rs = :ets.lookup(:upload_cache, key)
   found = (List.first(rs)) || {nil, nil}
   {:reply, elem(found, 1), state}
 end

 def handle_call(request, from, state) do
   # Call the default implementation from GenServer
   super(request, from, state)
 end

 def handle_cast({:update, item}, state) do
   item = Map.delete(item, :__struct__)
   :ets.insert(:upload_cache, {item.identifier, item})
   {:noreply, state}
 end

 def handle_cast({:delete, key}, state) do
   :ets.delete(:upload_cache, key)
   {:noreply, state}
 end

 def handle_cast(request, state) do
   super(request, state)
 end
end
