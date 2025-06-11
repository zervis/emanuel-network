defmodule Socialite.Groups.Group do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "groups" do
    field :name, :string
    field :description, :string
    field :location, Geo.PostGIS.Geometry
    field :radius_km, :float, default: 10.0
    field :is_public, :boolean, default: true
    field :avatar_url, :string
    field :cover_url, :string
    field :member_count, :integer, default: 0

    belongs_to :creator, Socialite.Accounts.User, foreign_key: :creator_id
    has_many :group_memberships, Socialite.Groups.GroupMembership
    has_many :members, through: [:group_memberships, :user]
    has_many :posts, Socialite.Posts.Post

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :description, :location, :radius_km, :is_public, :avatar_url, :cover_url, :creator_id])
    |> validate_required([:name, :creator_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_length(:description, max: 1000)
    |> validate_number(:radius_km, greater_than: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:creator_id)
  end
end
