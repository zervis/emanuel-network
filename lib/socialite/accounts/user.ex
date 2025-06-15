defmodule Socialite.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :first_name, :string
    field :last_name, :string
    field :avatar, :string
    field :bio, :string
    field :is_active, :boolean, default: true
    field :kudos_count, :integer, default: 0
    field :daily_kudos_credits, :integer, default: 100
    field :last_credits_reset, :date
    field :followers_count, :integer, default: 0
    field :following_count, :integer, default: 0
    field :gender, :string
    field :relationship_status, :string
    field :personality_type, :string
    field :birthdate, :date
    field :height, :integer  # Height in centimeters
    field :weight, :float    # Weight in kilograms
    field :address, :string
    field :city, :string
    field :state, :string
    field :country, :string
    field :postal_code, :string
    field :latitude, :float
    field :longitude, :float
    field :confirmed_at, :naive_datetime

    timestamps()
  end



  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :first_name, :last_name])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_required([:first_name, :last_name])
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :first_name,
      :last_name,
      :avatar,
      :bio,
      :gender,
      :relationship_status,
      :personality_type,
      :birthdate,
      :height,
      :weight,
      :address,
      :city,
      :state,
      :country,
      :postal_code,
      :latitude,
      :longitude
    ])
    |> validate_required([:first_name, :last_name])
    |> validate_height()
    |> validate_weight()
  end

  def location_changeset(user, attrs) do
    user
    |> cast(attrs, [:latitude, :longitude])
    |> validate_required([:latitude, :longitude])
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 80)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Socialite.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  def valid_password?(%Socialite.Accounts.User{password_hash: password_hash}, password)
      when is_binary(password_hash) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, password_hash)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  def verify_password(%__MODULE__{} = user, password) do
    valid_password?(user, password)
  end

  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email(validate_email: false)
  end

  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  def kudos_changeset(user, attrs) do
    user
    |> cast(attrs, [:kudos_count])
    |> validate_required([:kudos_count])
  end

  def credits_changeset(user, attrs) do
    user
    |> cast(attrs, [:daily_kudos_credits, :last_credits_reset])
    |> validate_required([:daily_kudos_credits, :last_credits_reset])
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :first_name,
      :last_name,
      :avatar,
      :bio,
      :gender,
      :relationship_status,
      :personality_type,
      :birthdate,
      :height,
      :weight,
      :address,
      :city,
      :state,
      :country,
      :postal_code,
      :latitude,
      :longitude
    ])
    |> validate_required([:email, :first_name, :last_name])
    |> validate_height()
    |> validate_weight()
  end

  def full_name(%__MODULE__{first_name: first_name, last_name: last_name}) do
    "#{first_name} #{last_name}"
  end

  @doc """
  Returns the user's avatar URL or a default avatar if none is set.
  """
  def avatar_url(%__MODULE__{avatar: avatar}) when is_binary(avatar) and avatar != "", do: avatar
  def avatar_url(_user), do: "/images/default-avatar.png"

  @doc """
  Returns the default avatar path.
  """
  def default_avatar_path, do: "/images/default-avatar.png"

  defp validate_height(changeset) do
    case get_field(changeset, :height) do
      nil -> changeset
      height when is_integer(height) ->
        if height >= 50 and height <= 300 do
          changeset
        else
          add_error(changeset, :height, "must be between 50 and 300 cm")
        end
      _ ->
        add_error(changeset, :height, "must be a valid number")
    end
  end

  defp validate_weight(changeset) do
    case get_field(changeset, :weight) do
      nil -> changeset
      weight when is_number(weight) ->
        if weight >= 20.0 and weight <= 500.0 do
          changeset
        else
          add_error(changeset, :weight, "must be between 20 and 500 kg")
        end
      _ ->
        add_error(changeset, :weight, "must be a valid number")
    end
  end

end
