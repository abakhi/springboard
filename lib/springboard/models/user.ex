defmodule SpringBoard.User do
  use SpringBoard.Web, :model
  import Comeonin.Bcrypt, only: [checkpw: 2]
  alias SpringBoard.Repo

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    # TODO: Constraint to check that the parent_id exists
    field :parent_id, :string
    field :pin, :string, virtual: true
    field :pin_hash, :string
    field :phone_number, :string
    field :email, :string
    field :dob, Ecto.Date
    field :last_seen, Ecto.DateTime
    # account types: personal, commercial, ngo
    field :account_type, :string, default: "personal"
    field :metadata, :map, default: %{}
    field :verified, :boolean, default: false
    field :gcm_id, :string

    has_many :apps, SpringBoard.App

    timestamps
  end

  @account_types       ~w(personal commercial ngo)
  @email_regex ~r/^([\w_\.\-\+])+\@([\w\-]+\.)+([\w]{2,10})+$/
  @required_fields ~w(first_name last_name pin phone_number email dob)
  @optional_fields ~w(metadata pin_hash parent_id last_seen account_type gcm_id)

  @pin_length  6

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_length(:first_name, min: 1)
    |> validate_length(:last_name, min: 1)
    |> validate_format(:email, @email_regex)
    |> unique_constraint(:email)
    |> validate_format(:phone_number, ~r/^[0-9]*$/)
    |> unique_constraint(:phone_number)
    |> validate_pin
    |> put_uuid
  end

  def registration_changeset(model, params \\ :empty) do
    model
    |> changeset(params)
    |> cast(params, ~w(pin), [])
    |> validate_length(:pin, is: 6)
    |> put_pin_hash
  end

  @spec valid_pin?(String.t) :: boolean
  def valid_pin?(pin) do
    ints_strs =
      ((0..9)
       |> Enum.to_list
       |> Enum.map(&to_string/1))

    String.length(pin) == @pin_length &&
    (pin
    |> String.split("")
    |> Enum.filter(&(&1 != ""))
    |> Enum.all?(&(&1 in ints_strs)))
  end

  def validate_pin(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{pin: pin}} ->
        if valid_pin?(pin) do
          changeset
        else
          add_error(changeset, :pin, "Pin must be contain only digits")
        end
      _ ->
        changeset
    end
  end

  def put_dob(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{dob: dob}} ->
        put_change(changeset, :dob, Utils.parse_date(dob))
      _ ->
        changeset
    end
  end

  @doc """
  Encrypts the pin and saves the hash in the user's pin_hash field
  """
  def put_pin_hash(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{pin: pin}} ->
        put_change(changeset, :pin_hash, Comeonin.Bcrypt.hashpwsalt(pin))
      _ ->
        changeset
    end
  end

  @doc """
  Authenticate a user by phone number and pin
  #TODO: Ensure pin only contains numeric characters
  """
  def maybe_authenticate(phone_number, pin) do
    pin = to_string(pin)
    formatted_number = Utils.format_phone_number(phone_number)
    user = Repo.get_by(__MODULE__, phone_number: formatted_number)

    cond do
      user && checkpw(pin, user.pin_hash) ->
        update(user, %{last_seen: Ecto.DateTime.utc})
        {:ok, user}
      user = %User{} ->
        {:error, :unauthorized}
      true ->
        {:error, :not_found}
    end
  end

  def create(params) do
    changeset = registration_changeset(%User{}, params)
    with {:ok, user} <- Repo.insert(changeset) do
      # some stuff to-do after creating user, eg: email alert, custom hooks etc
      {:ok, user}
    end
  end

  @doc "Returns user's created by this user"
  @spec children(String.t) :: [Ecto.Schema.t] | no_return
  def children(parent_id) do
    from( u in __MODULE__,
          where: u.parent_id == ^parent_id,
          select: u)
  end

  def fullname(user = %__MODULE__{}), do: "#{user.first_name} #{user.last_name}"
end
