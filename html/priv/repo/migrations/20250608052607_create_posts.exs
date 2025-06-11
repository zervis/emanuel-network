defmodule Socialite.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :content, :text, null: false
      add :post_type, :string, default: "text"
      add :image_url, :string
      add :location, :geometry
      add :is_public, :boolean, default: true
      add :likes_count, :integer, default: 0
      add :comments_count, :integer, default: 0
      add :author_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :group_id, references(:groups, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:posts, [:author_id])
    create index(:posts, [:group_id])
    create index(:posts, [:location], using: :gist)
    create index(:posts, [:is_public])
    create index(:posts, [:post_type])
    create index(:posts, [:inserted_at])
  end
end
