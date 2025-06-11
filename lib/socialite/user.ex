defmodule Socialite.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    field :password_hash, :string
    field :avatar, :string
    field :bio, :string
    field :is_active, :boolean, default: true
    field :kudos_count, :integer, default: 0
    field :daily_kudos_credits, :integer, default: 100
    field :last_credits_reset, :date
    field :followers_count, :integer, default: 0
    field :following_count, :integer, default: 0

    # Virtual fields for registration
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    has_many :posts, Socialite.Post
    has_many :comments, Socialite.Comment
    has_many :sent_messages, Socialite.Message, foreign_key: :sender_id
    has_many :received_messages, Socialite.Message, foreign_key: :recipient_id
    has_many :given_kudos, Socialite.Kudos, foreign_key: :giver_id
    has_many :received_kudos, Socialite.Kudos, foreign_key: :receiver_id

    # Follow relationships
    has_many :following_relationships, Socialite.Follow, foreign_key: :follower_id
    has_many :follower_relationships, Socialite.Follow, foreign_key: :followed_id
    has_many :following, through: [:following_relationships, :followed]
    has_many :followers, through: [:follower_relationships, :follower]

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name, :email, :password, :password_confirmation, :avatar, :bio, :is_active])
    |> validate_required([:first_name, :last_name, :email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:password, min: 6, message: "must be at least 6 characters")
    |> validate_confirmation(:password, message: "passwords do not match")
    |> unique_constraint(:email, message: "email already taken")
    |> put_password_hash()
  end

  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
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

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset

  def full_name(%__MODULE__{first_name: first_name, last_name: last_name}) do
    "#{first_name} #{last_name}"
  end

  def verify_password(%__MODULE__{password_hash: password_hash}, password) do
    Bcrypt.verify_pass(password, password_hash)
  end
end
