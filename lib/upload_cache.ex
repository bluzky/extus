defmodule ExTus.UploadInfo do
  defstruct [identifier: "", filename: "", offset: 0, size: 0, started_at: nil, options: %{}]
end

defmodule ExTus.UploadCache do
  use GenServer
  require Logger

  # Client
  @clean_interval Application.get_env(:extus, :clean_interval, nil)
  @expired_after (Application.get_env(:extus, :expired_after, 0) / 1000)
	
	def cache_storage() do
		Application.get_env(:extus, :cache_storage) || Extus.Cache.RedisStorage
	end

 def start_link() do
   GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
 end

 def init(state) do
	 {:ok, conn} = cache_storage().init()
	 
   if @clean_interval do
     Process.send_after(self, :clean, @clean_interval)
   end
	 
   {:ok, %{conn: conn}}
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
	
 def all() do
   GenServer.call(__MODULE__, :all)
 end

 # Server (callbacks)

 def handle_call({:put, item}, _from, %{conn: conn} = state) do
   item = Map.delete(item, :__struct__)
   rs = cache_storage().put(conn, item.identifier, item)
   {:reply, rs, state}
 end

 def handle_call({:get, key}, _from, %{conn: conn} = state) do
    rs = cache_storage().get(conn, key)
    {:reply, rs, state}
  end
	
	def handle_call(:all, _from, %{conn: conn} = state) do
    rs = cache_storage().all(conn)
    {:reply, rs, state}
  end

 def handle_call(request, from, state) do
   # Call the default implementation from GenServer
   super(request, from, state)
 end

 def handle_cast({:update, item}, %{conn: conn} = state) do
   item = Map.delete(item, :__struct__)
   cache_storage().update(conn, item.identifier, item)
   {:noreply, state}
 end

 def handle_cast({:delete, key}, %{conn: conn} = state) do
	 cache_storage().del(conn, key)
   {:noreply, state}
 end

 def handle_cast(request, state) do
   super(request, state)
 end

 def handle_info(:clean, state) do
   Logger.info "Run ExTus cleaner at: #{inspect DateTime.utc_now}"
   Process.send_after(self, :clean, @clean_interval)
   do_cleaning(state)
   {:noreply, state}
 end

 def do_cleaning(%{conn: conn} = state) do
   cache_storage().all(conn)
   |> Enum.filter(fn data ->
     {:ok, time, _} = DateTime.from_iso8601(data.started_at)
     time = DateTime.to_unix(time)
     now = DateTime.utc_now |> DateTime.to_unix()
     (now - time) > @expired_after
   end)
   |> Enum.map(fn (%{identifier: key} = data) ->
     storage = Application.get_env(:extus, :storage)
     if storage, do: storage.abort_upload(data)
     cache_storage().del(conn, key)
   end )
 end
end
