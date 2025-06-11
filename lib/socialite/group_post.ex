defmodule Socialite.GroupPost do
  use Ecto.Schema
  import Ecto.Changeset

  schema "group_posts" do
    field :content, :string
    field :image_url, :string
    field :likes_count, :integer, default: 0

    belongs_to :user, Socialite.User
    belongs_to :group, Socialite.Group
    has_many :group_post_comments, Socialite.GroupPostComment

    timestamps()
  end

  @doc false
  def changeset(group_post, attrs) do
    group_post
    |> cast(attrs, [:content, :image_url, :user_id, :group_id])
    |> validate_required([:content, :user_id, :group_id])
    |> validate_length(:content, min: 1, max: 1000)
  end
end
