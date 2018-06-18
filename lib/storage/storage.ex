defmodule ExTus.Storage do
  @callback initiate_file(String.t()) :: Tuple.type()
  @callback put_file(map, String.t()) :: Tuple.type()
  @callback append_data(map, iodata) :: Tuple.type()
  @callback complete_file(map) :: Tuple.type()
  @callback abort_upload(map) :: Tuple.type()
  @callback url(String.t()) :: String.t()
  @callback delete(String.t()) :: Tuple.typ()

  defmacro __using__(_) do
    quote do
      @behaviour ExTus.Storage

      def url(nil), do: nil
      def url(path), do: path
      def storage_dir(), do: ""
      def filename(file), do: file

      defoverridable url: 1, storage_dir: 0, filename: 1
    end
  end

  defmacro extends(module) do
    module = Macro.expand(module, __CALLER__)
    functions = module.__info__(:functions)

    signatures =
      Enum.map(functions, fn {name, arity} ->
        args =
          if arity == 0 do
            []
          else
            Enum.map(1..arity, fn i ->
              {String.to_atom(<<?x, ?A + i - 1>>), [], nil}
            end)
          end

        {name, [], args}
      end)

    quote do
      defdelegate unquote(signatures), to: unquote(module)
      defoverridable unquote(functions)
    end
  end
end
