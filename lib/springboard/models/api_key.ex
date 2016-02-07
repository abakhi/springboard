defmodule SpringBoard.ApiKey do
  use SpringBoard.Web, :model
  alias SpringBoard.{KeyGen, Repo}

  @api_envs ~w(test live)

  schema "api_keys" do
    field :secret_key, :string
    field :public_key, :string
    field :metadata, :map, default: %{}
    field :env, :string, default: "test"
    belongs_to :app, SpringBoard.App

    timestamps
  end

  @required_fields ~w(app_id secret_key public_key)
  @optional_fields ~w(env metadata)

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  @api_key_regex ~r/[sp]k_(live|test)_(.*)/

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_inclusion(:env, @api_envs)
    |> put_uuid
  end

  def validate_keys(changeset) do
    changeset
    |> validate_format(:secret_key, @api_key_regex)
    |> validate_format(:public_key, @api_key_regex)
    |> unique_constraint(:secret_key)
    |> unique_constraint(:public_key)
  end

  def put_keys(changeset) do
    env = Map.get(changeset.changes, :env) || changeset.model.env
    case env do
      "test" ->
        changeset
        |> put_change(:secret_key, KeyGen.new_key(:test, :secret))
        |> put_change(:public_key, KeyGen.new_key(:test, :public))
      "live" ->
        changeset
        |> put_change(:secret_key, KeyGen.new_key(:live, :secret))
        |> put_change(:public_key, KeyGen.new_key(:live, :public))
    end
  end

  def valid_secret_key?(key) do
    api_key = Repo.get_by(SpringBoard.ApiKey, secret_key: key)
    if api_key do
      Repo.preload(api_key, :app)
    else
      false
    end
  end

  def create(params) do
    changeset(%ApiKey{}, params)
    |> put_keys
    |> validate_keys
    |> Repo.insert
  end
end
