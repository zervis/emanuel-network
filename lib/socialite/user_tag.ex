defmodule Socialite.UserTag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_tags" do
    field :proficiency_level, :integer, default: 1
    field :is_public, :boolean, default: true

    belongs_to :user, Socialite.User
    belongs_to :tag, Socialite.Tag

    timestamps()
  end

  @doc false
  def changeset(user_tag, attrs) do
    user_tag
    |> cast(attrs, [:user_id, :tag_id, :proficiency_level, :is_public])
    |> validate_required([:user_id, :tag_id])
    |> validate_inclusion(:proficiency_level, 1..5)
    |> unique_constraint([:user_id, :tag_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:tag_id)
  end
end
