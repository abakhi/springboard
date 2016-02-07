defmodule SpringBoard.App do
  use SpringBoard.Web, :model

  schema "apps" do
    field :name, :string
    field :email, :string
    field :webhook_url, :string
    field :metadata, :map
    field :verified, :boolean, default: false
    field :link, :string
    belongs_to :user, SpringBoard.User

    timestamps
  end

  @required_fields ~w(name email)
  @optional_fields ~w(metadata verified link  webhook_url)

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> put_uuid
  end

  def create(params) do
    changeset(%App{}, params)
    |> Repo.insert
  end
end
