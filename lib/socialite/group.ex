defmodule Socialite.Group do
  use Ecto.Schema
  import Ecto.Changeset

  schema "groups" do
    field :name, :string
    field :description, :string
    field :lat, :float
    field :lng, :float
    field :address, :string
    field :members_count, :integer, default: 0
    field :is_public, :boolean, default: true
    field :avatar, :string
    field :banner, :string

    belongs_to :creator, Socialite.User

    has_many :group_members, Socialite.GroupMember
    has_many :members, through: [:group_members, :user]
    has_many :group_posts, Socialite.GroupPost
    has_many :group_events, Socialite.GroupEvent

    timestamps(type: :naive_datetime)
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :description, :address, :creator_id, :is_public, :avatar, :banner, :lat, :lng])
    |> validate_required([:name, :creator_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 1000)
    |> validate_number(:lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:lng, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
  end


end
