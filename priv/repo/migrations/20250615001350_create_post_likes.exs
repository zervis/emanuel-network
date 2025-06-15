defmodule Socialite.Repo.Migrations.CreatePostLikes do
  use Ecto.Migration

  def change do
    create table(:post_likes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:post_likes, [:user_id])
    create index(:post_likes, [:post_id])
    create unique_index(:post_likes, [:user_id, :post_id])
  end
end
