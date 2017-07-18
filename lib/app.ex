defmodule ExTus.App do
  @moduledoc false
  use Application

  def start(_, _) do
    import Supervisor.Spec
    children = [
      worker(ExTus.UploadCache, [])
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
