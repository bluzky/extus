defmodule ExTus.Controller do
  defmacro __using__(_) do
    quote do
      def options(conn, _params)do
        ExTus.Actions.options(conn)
      end

      def head(conn, %{"file" => file} = params)do
        ExTus.Actions.head(conn, file)
      end

      def patch(conn, %{"file" => file} = params)do
        ExTus.Actions.patch(conn, file, &on_complete_upload/1)
      end

      def post(conn, _params)do
        ExTus.Actions.post(conn, &on_begin_upload/1)
      end

      def delete(conn, %{"file" => file} = params)do
        ExTus.Actions.delete(conn, file)
      end

      def on_begin_upload(_) do

      end

      def on_complete_upload(_) do

      end

      defoverridable [on_begin_upload: 1, on_complete_upload: 1]
    end
  end
end
