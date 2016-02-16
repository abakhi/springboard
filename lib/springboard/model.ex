defmodule SpringBoard.Model do
  alias SpringBoard.UUID
  alias Ecto.Date
  import Ecto.Changeset, only: [add_error: 3, validate_change: 3]

  defmacro __before_compile__(_env) do
    quote do
      alias Mix.Tasks.Swagger

      @doc """
      Returns all required or optional fields, specified by the parameter passed

      ### Possible arguments
      * `:required`
      * `:optional`
      """
      @spec fields(atom) :: Keyword.t
      def fields(:required) do
        @required_fields
        |> Enum.map(&String.to_atom/1)
        |> filter_model_fields
      end

      def fields(:optional) do
        @optional_fields
        |> Enum.map(&String.to_atom/1)
        |> filter_model_fields
      end

      defp filter_model_fields(some_fields) do
        Enum.filter(__MODULE__.__schema__(:types),
          fn {field, type} -> field in some_fields end)
      end

      @doc """
      Returns list of parameters to use in the generated JSON API file for
      Swagger UI

      ### Parameter format
      `{
        type: "string",
        required: true,
        name: "type",
        in: "path",
        description: ""
      }`

      For more info, see #http://swagger.io/specification/#parameterObject
      """
      @spec swagger_route_params :: Enum.t
      def swagger_route_params do
        params =
        (Enum.map(fields(:required) |> Keyword.keys,
                  &(Swagger.build_parameter(&1)))
         ++
         Enum.map(fields(:optional) |> Keyword.keys,
                  &(Swagger.build_parameter(&1, false))))
        exclude_params = Application.get_env(:swaggerdoc, :exclude_parameters)
        Enum.filter(params, &(not(&1[:name] in exclude_params)))
      end
    end
  end

  defmacro __using__(opts) do
    quote do
      use Ecto.Model
      use Ecto.Model.Callbacks
      alias Decimal, as: D
      import Ecto.Model
      import SpringBoard.Model
      import SpringBoard, only: [app_env: 1, app_env: 2]
      alias __MODULE__

      opts = unquote(opts)
      @base_module  opts[:base]
      @repo         opts[:repo]

      @primary_key {:id, :string, []}
      @foreign_key_type :string

      @before_compile SpringBoard.Model

      @doc """
      Teturns a record by the given *id*; otherwis returns nil
      """
      @spec by_id(Integer.t) :: Ecto.Model.t | nil | no_return
      def by_id(id) do
        @repo.get(__MODULE__, id)
      end

      @doc """
      Returns all the records that belong to this model
      """
      @spec all :: Ecto.Model.t | nil | no_return
      def all(preload_assocs \\ false) do
        query = @repo.all(__MODULE__)
        if preload_assocs, do: maybe_preload(query), else: query
      end

      @doc """
      Ecto *after_load* hook for preloading associated records
      """
      def maybe_preload(query) do
        query |> @repo.preload(associations)
      end

      @doc """
      Returns a list of all the model fields that map to associated models
      """
      def associations do
        changeset = struct(__MODULE__) |> __MODULE__.changeset(%{})
        changeset.types
        |> Enum.filter(fn {_k, v} -> is_tuple(v) && elem(v,0) == :assoc end)
        |> Enum.map(fn {k, _v} -> Inflex.camelize(k) |> Inflex.singularize end)
        |> Enum.map(&(Module.concat(@base_module , &1)))
      end

      @doc "Updates a record"
      # Update by record id
      @spec update(String.t, map) :: Ecto.Schema.t | nil | no_return
      def update(record_id, params) when is_binary(record_id) do
        record_id
        |> __MODULE__.by_id
        |> update(params)
      end

      @spec update(Ecto.Schema.t, map) :: Ecto.Schema.t
      def update(model_or_changeset, params) do
        cast(model_or_changeset, params, Map.keys(params), ~w())
        |> @repo.update
      end

      @doc "Delete a #{__MODULE__}"
      def delete(id) do
        @repo.get!(__MODULE__, id) |> @repo.delete!
      end

      @doc "Return's record at the given index"
      @spec at(integer) :: Ecto.Schema.t | nil | no_return
      def at(index) do
        from(x in __MODULE__, select: x, offset: ^index, limit: 1)
        |> @repo.one
      end

      def count, do: Ectoo.count(__MODULE__) |> @repo.one
      def max(field), do: Ectoo.max(__MODULE__, field) |> @repo.one
      def min(field), do: Ectoo.min(__MODULE__, field) |> @repo.one
      def avg(field), do: Ectoo.avg(__MODULE__, field) |> @repo.one
      def sum(field), do: Ectoo.sum(__MODULE__, field) |> @repo.one

      defoverridable [associations: 0, maybe_preload: 1, update: 2]
    end
  end

  @doc "Insert a UUID into the model or changeset"
  def put_uuid(%Ecto.Changeset{} = changeset) do
    if changeset.model.__meta__.state == :built do
      prefix =
        (Map.to_list(changeset.model)[:__struct__]
        |> UUID.generate_prefix)

      Ecto.Changeset.put_change(changeset, :id, UUID.generate(prefix))
    else
      changeset
    end
  end

  def put_uuid(model) do
    if model.__meta__.state == :built do
      prefix = UUID.generate_prefix(model)
      Map.put(model, :id, UUID.generate(prefix))
    else
      model
    end
  end

  @doc """
  Update a model or changeset

  ## Example
  iex> user = User.at(3)
  iex> update_model(user, %{last_seen: Ecto.DateTime.utc})
  """
  @spec update_model(Ecto.Schema.t, map) :: Ecto.Schema.t | nil | no_return
  def update_model(changeset = %Ecto.Changeset{}, params) do
    update_model(changeset.model, params)
  end

  @spec update_model(Ecto.Model.t, map) :: any
  def update_model(struct, params) do
    model_from_struct(struct)
    |> apply(:update, [struct, params])
  end

  @doc """
  Builds a model name from the struct object. Useful for guessing model
  names given only the struct
  """
  def model_from_struct(struct) do
    {_prefix, source} = struct.__meta__.source
    base_model =
      (source
      |> Inflex.camelize
      |> Inflex.singularize)

    Module.concat(Mix.Phoenix.base, base_model)
  end

  @doc "Convert an Ecto model struct to a plain map"
  @spec sanitize(Ecto.Model.t) :: map
  def sanitize(struct) when is_map(struct) do
    modelmap =
    (if Map.has_key?(struct, :__meta__) do
       fields = model_from_struct(struct).associations
       model =
       (struct
        |> Map.from_struct
        |> Map.drop([:__meta__] ++ fields))
       model
     else
       struct
     end)

    to_delete =
      Enum.filter(modelmap, fn {k, v} ->
        case v do
          %Ecto.Association.NotLoaded{} ->
            true
          _ ->
            false
        end
      end)

    Map.drop(modelmap, Keyword.keys(to_delete))
  end

  @doc """
  Callback for Mix.Tasks.Swagger's `build_route_params` config.

  Returns list of Swagger parameters objects based on the model's fields.
  """
  @spec build_route_params(atom) :: Map.t
  def build_route_params(module) do
    apply(module, :swagger_route_params, [])
  end

  @doc """
  Checks for the existence of related record using the *id* field of the related
  model. Useful for when you want to enforce foreign key contraints without
  using the *belongs_to* attribute, say, a string field.

  Options

  * :model -  Ecto model to query
  * :message - Error message when the record does not exist
  """
  def validate_foreign_key(changeset, field, opts) do
    model = opts[:model]
    validate_change changeset, field, fn _field, id ->
      model_name= Module.split(model) |> Enum.at(-1) |> String.downcase
      message = opts[:message] || "#{model_name} #{id} does not exist"

      case @repo.get_by(model, id: id) do
        nil ->
          [{field, message}]
        _ ->
          []
      end
    end
  end

  @doc """
  Validates a given credit card number. The *field* indicates the name of the
  field containing the credit card number.
  """
  def validate_credit_card(changeset, field \\ :card_number, opts \\ []) do
    validate_change changeset, field, fn _field, number ->
      message = opts[:message] || "Invalid credit card number"
      if CreditCard.valid?(to_string(number)) do
        []
      else
        [{field, message}]
      end
    end
  end

  def validate_date(changeset, field, opts \\ []) do
    validate_change changeset, field, fn _field, date ->
      error  = ((gt = opts[:greater_than]) && date_compare(date, gt, :gt, opts)) ||
               ((lt = opts[:less_than]) && date_compare(date, lt, :lt, opts)) ||
               ((eq = opts[:equal_to]) && date_compare(date, eq, :eq, opts))

      if error, do: [{field, error}], else: []
    end
  end

  defp date_compare(given_date, check_date, :gt, opts) do
    case Ecto.Date.compare(given_date, check_date) do
      val when val in [:lt, :eq]  -> message(opts, "#{given_date} should be older than #{check_date}")
      :gt -> nil
    end
  end

  defp date_compare(given_date, check_date, :lt, opts) do
    case Ecto.Date.compare(given_date, check_date) do
      val when val in [:gt, :eq]  ->
        message(opts, "#{given_date} should be newer than #{check_date}")
      :lt -> nil
    end
  end

  defp date_compare(given_date, check_date, :eq, opts) do
    case Ecto.Date.compare(given_date, check_date) do
      val when val in [:lt, :gt] ->
        message(opts, "#{given_date} should not be the same as  #{check_date}")
      :eq -> nil
    end
  end

  defp message(opts, default) do
    Keyword.get(opts, :message, default)
  end
end
