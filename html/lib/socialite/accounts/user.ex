defmodule Socialite.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :username, :string
    field :first_name, :string
    field :last_name, :string
    field :bio, :string
    field :avatar_url, :string
    field :cover_url, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :confirmed_at, :naive_datetime
    field :location, Geo.PostGIS.Geometry
    field :kudos_count, :integer, default: 0
    field :daily_kudos, :integer, default: 100
    field :last_kudos_reset, :date
    field :is_active, :boolean, default: true

    has_many :sent_messages, Socialite.Messages.Message, foreign_key: :sender_id
    has_many :received_messages, Socialite.Messages.Message, foreign_key: :recipient_id
    has_many :posts, Socialite.Posts.Post
    has_many :kudos_given, Socialite.Kudos.Kudo, foreign_key: :giver_id
    has_many :kudos_received, Socialite.Kudos.Kudo, foreign_key: :receiver_id
    has_many :group_memberships, Socialite.Groups.GroupMembership
    has_many :groups, through: [:group_memberships, :group]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :first_name, :last_name, :bio, :avatar_url, :cover_url, :password, :password_confirmation, :location])
    |> validate_required([:email, :username, :first_name, :last_name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_length(:username, min: 3, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, message: "can only contain letters, numbers, and underscores")
    |> validate_length(:password, min: 6, max: 72)
    |> validate_confirmation(:password)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> maybe_hash_password()
    |> reset_daily_kudos_if_needed()
  end

  defp maybe_hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      changeset
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
      |> delete_change(:password_confirmation)
    else
      changeset
    end
  end

  defp reset_daily_kudos_if_needed(changeset) do
    today = Date.utc_today()
    last_reset = get_field(changeset, :last_kudos_reset)

    if last_reset != today do
      changeset
      |> put_change(:daily_kudos, 100)
      |> put_change(:last_kudos_reset, today)
    else
      changeset
    end
  end

  def verify_password(user, password) do
    Bcrypt.verify_pass(password, user.password_hash)
  end
end
