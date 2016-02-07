defmodule Springboard.Serializer do
  defmacro __using__(_) do
    quote do
      use Remodel
      import unquote(__MODULE__)

      attributes [:id, :created, :updated, :metadata, :url, :object]

      def created(record) do
        "#{record.inserted_at}"
      end

      def updated(record) do
        "#{record.updated_at}"
      end

      def url(record) do
        [_h|[t|_]] =  Module.split(record.__struct__)
        resource = Inflex.pluralize(t) |> String.downcase
        object_id = id(record)
        "v1/#{resource}/#{object_id}"
      end

      def object(record) do
        "#{get_object(record)}"
      end

      # Set null metadata columns to %{}
      def metadata(record) do
         unless record.metadata, do: %{}, else: record.metadata
      end
    end
  end

  @doc "Returns the model name"
  def get_object(record) do
    {_prefix, source} = record.__meta__.source
    source
    |> Inflex.singularize
    |> String.downcase
  end

  @doc """
  Helper for serializing Ecto associations.

  ### Example
  assoc_attribute :transfers

  This will translates into:
  ```
  attribute :transfers, if: :include_transfers?

  def transfers(record) do
   TransferSerializer.to_map(record.transfers)
  end

  def include_transfers?(record) do
    case record.transfers do
      %Ecto.Association.NotLoaded{} ->
        false
      _ ->
        true
    end
  end
  ```
  Essentally what happens is that two functions are generated. One function checks
  if the associated records have been loaded. And if they are loaded, it then
  calls the function (name points to the key in the record) to retrive and
  serialize the associated records.

  TODO: Allow setting of func_name and attr getter key
  :identity, if: identity?, key: :identity_card
  """
  defmacro assoc_attribute(attr, opts \\ []) do
    quote bind_quoted: [attr: attr, opts: opts], location: :keep do
      func_name = String.to_atom("include_#{attr}?")
      attribute attr, if: func_name
      #assoc_getter_key = opts[:key] || attr
      define_assoc_getter unquote(attr)

      def unquote(func_name)(record) do
        case apply(Map, :get, [record, unquote(attr)])  do
          %Ecto.Association.NotLoaded{} ->
            false
          nil ->
            false
          _ ->
            true
        end
      end
    end
  end

  @doc "Adds multiple assoc_attribute tags"
  @spec assoc_attributes(list(atom)) :: any
  defmacro assoc_attributes(attrs) do
    quote do
      attrs = unquote(attrs)
      for x <- attrs do
        assoc_attribute x
      end
    end
  end

  @doc """
  Defines the function that actually retrieves the associated records and
  serializes them using the model's serializer. It assumes that the serializer
  is named as AppName.ModelSerializer.
  """
  defmacro define_assoc_getter(attr) do
    quote location: :keep do
      def unquote(attr)(record) do
        serializer = get_serializer(unquote(attr))
        assoc_record = apply(Map, :get, [record, unquote(attr)])
        apply(serializer, :to_map, [assoc_record])
      end
    end
  end

  def get_serializer(thing) do
    model = Inflex.singularize(thing) |> Inflex.camelize
    :application.get_application
    |> String.capitalize
    |> Module.concat("#{model}Serializer")
  end
end
