defmodule SpringBoard.Repo do
  # FIX: dynamically set OTP app to use via configurations
  # use Ecto.Repo, otp_app: Application.get_env(:springboard, :otp_app)

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)
      use Ecto.Repo, otp_app: opts[:otp_app]
      import Ecto.Query, only: [from: 2]
      import SpringBoard.Web.Response, only: [render_error: 2, render_json: 2]
      import SpringBoard.Web.Request.Error, only: [not_found: 0]
      import SpringBoard.Web.Controller, only: [parse_expand_qs: 1]

      @scrivener_defaults page_size: 20

      @doc """
      Get model by id or return 404
      """
      def get_or_404(conn, model, field_qs, fields_to_expand \\ []) do
        to_expand = parse_expand_qs(conn.params["expand"]) ++ fields_to_expand
        maybe_get = if(is_list(field_qs), do: &get_by/2, else: &get/2)

        case maybe_get.(model, field_qs) do
          nil ->
            render_error(conn, not_found)
          object ->
            unless Enum.empty?(to_expand) do
              render_json(conn, preload(object, expandable_fields(model, to_expand)))
            else
              render_json(conn, object)
          end
        end
      end

      # TODO: replace with handrolled paginator
      @spec paginate(Ecto.Query.t, map | Keyword.t) :: map
      def paginate(query, opts \\ []) do
        Scrivener.paginate(__MODULE__, @scrivener_defaults, query, opts)
        |> Map.from_struct
      end

      @spec by_user(Ecto.Model.t, String.t) :: [Ecto.Schema.t] | no_return
      def by_user(query, user_id) do
        from obj in query, where: obj.user_id == ^user_id, select: obj
      end

      ## PRIVATE

      @doc "Returns list of model fields that can be preloaded"
      @spec expandable_fields(Ecto.Model.t, list(atom)) :: list(atom)
      def expandable_fields(model, []), do: []

      def expandable_fields(model, fields_to_expand) do
        # return intersection of given fields and the actually existing fields
        MapSet.new(fields_to_expand)
        |> MapSet.intersection(MapSet.new(model.associations))
        |> MapSet.to_list
      end
    end
  end
end
