defmodule Socialite.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "posts" do
    field :title, :string
    field :content, :string
    field :post_type, :string, default: "text"
    field :image_url, :string
    field :location, Geo.PostGIS.Geometry
    field :is_public, :boolean, default: true
    field :likes_count, :integer, default: 0
    field :comments_count, :integer, default: 0

    belongs_to :author, Socialite.Accounts.User, foreign_key: :author_id
    belongs_to :group, Socialite.Groups.Group, foreign_key: :group_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :content, :post_type, :image_url, :location, :is_public, :author_id, :group_id])
    |> validate_required([:content, :author_id])
    |> validate_length(:title, max: 200)
    |> validate_length(:content, min: 1, max: 5000)
    |> validate_inclusion(:post_type, ["text", "image", "news", "event"])
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:group_id)
  end
end
