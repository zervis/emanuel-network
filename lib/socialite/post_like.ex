defmodule Socialite.PostLike do
  use Ecto.Schema
  import Ecto.Changeset

  schema "post_likes" do
    belongs_to :user, Socialite.User
    belongs_to :post, Socialite.Post

    timestamps()
  end

  def changeset(post_like, attrs) do
    post_like
    |> cast(attrs, [:user_id, :post_id])
    |> validate_required([:user_id, :post_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:post_id)
    |> unique_constraint([:user_id, :post_id])
  end
end
