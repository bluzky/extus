defmodule ExTus.UploadInfo do
  defstruct identifier: "", filename: "", offset: 0, size: 0, started_at: nil, options: %{}
end

defmodule ExTus.UploadCache do
  use GenServer
  require Logger

  # Client
  @clean_interval Application.get_env(:extus, :clean_interval, nil)
  @expired_after Application.get_env(:extus, :expired_after, 0) / 1000

  def start_link() do
    #  table = :ets.new(:upload_cache, [:named_table, :set, :protected])
    PersistentEts.new(:upload_cache, "upload_cache.tab", [:named_table, :set, :public])
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    if @clean_interval do
      Process.send_after(self(), :clean, @clean_interval)
    end

    {:ok, state}
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
    found = List.first(rs) || {nil, nil}
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

  def handle_info(:clean, state) do
    Logger.info("Run ExTus cleaner at: #{inspect(DateTime.utc_now())}")
    Process.send_after(self(), :clean, @clean_interval)
    do_cleaning()
    {:noreply, state}
  end

  def do_cleaning() do
    :ets.tab2list(:upload_cache)
    |> Enum.filter(fn {_, data} ->
      {:ok, time, _} = DateTime.from_iso8601(data.started_at)
      time = DateTime.to_unix(time)
      now = DateTime.utc_now() |> DateTime.to_unix()
      now - time > @expired_after
    end)
    |> Enum.map(fn {key, data} ->
      storage = Application.get_env(:extus, :storage)
      if storage, do: storage.abort_upload(data)
      :ets.delete(:upload_cache, key)
    end)
  end
end
