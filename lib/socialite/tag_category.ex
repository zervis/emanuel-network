defmodule Socialite.TagCategory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tag_categories" do
    field :name, :string
    field :description, :string
    field :icon, :string
    field :color, :string
    field :order_index, :integer, default: 0

    has_many :tags, Socialite.Tag, foreign_key: :category_id

    timestamps()
  end

  @doc false
  def changeset(tag_category, attrs) do
    tag_category
    |> cast(attrs, [:name, :description, :icon, :color, :order_index])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 50)
    |> unique_constraint(:name)
  end
end
