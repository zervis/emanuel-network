defmodule Socialite.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tags" do
    field :name, :string
    field :description, :string
    field :usage_count, :integer, default: 0
    field :is_active, :boolean, default: true

    belongs_to :category, Socialite.TagCategory, foreign_key: :category_id
    many_to_many :users, Socialite.User, join_through: Socialite.UserTag

    timestamps()
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :description, :category_id, :usage_count, :is_active])
    |> validate_required([:name, :category_id])
    |> validate_length(:name, min: 2, max: 50)
    |> unique_constraint([:name, :category_id])
    |> foreign_key_constraint(:category_id)
  end
end
