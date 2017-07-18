defmodule ExTus.Storage do

  @callback initiate_file(String.t) :: Tuple.type
  @callback put_file(map, String.t) :: Tuple.type
  defmacro __using__(_) do
    quote do
      def initiate_file(file) do

      end

      def put_file(file, destination) do

      end

      def append_data(file_identifier, data) do

      end

      def complete_filte(file_identifier) do

      end

      def url(file) do

      end

      def delete(file) do

      end
    end
  end
end
