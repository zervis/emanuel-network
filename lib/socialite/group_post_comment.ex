defmodule Socialite.GroupPostComment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "group_post_comments" do
    field :content, :string

    belongs_to :user, Socialite.User
    belongs_to :group_post, Socialite.GroupPost

    timestamps()
  end

  @doc false
  def changeset(group_post_comment, attrs) do
    group_post_comment
    |> cast(attrs, [:content, :user_id, :group_post_id])
    |> validate_required([:content, :user_id, :group_post_id])
    |> validate_length(:content, min: 1, max: 500)
  end
end
