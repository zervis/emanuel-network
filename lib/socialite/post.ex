defmodule Socialite.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :content, :string
    field :image_url, :string
    field :likes_count, :integer, default: 0

    belongs_to :user, Socialite.User
    has_many :comments, Socialite.Comment

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:content, :image_url, :likes_count, :user_id])
    |> validate_required([:content, :user_id])
    |> validate_length(:content, min: 1, max: 5000)
    |> foreign_key_constraint(:user_id)
  end
end
