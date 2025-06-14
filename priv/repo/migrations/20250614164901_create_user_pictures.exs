defmodule Socialite.Repo.Migrations.CreateUserPictures do
  use Ecto.Migration

  def change do
    create table(:user_pictures) do
      add :url, :string, null: false
      add :is_avatar, :boolean, default: false, null: false
      add :order, :integer, default: 0, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:user_pictures, [:user_id])
    create index(:user_pictures, [:user_id, :is_avatar])
    create index(:user_pictures, [:user_id, :order])

    # Ensure only one avatar per user
    create unique_index(:user_pictures, [:user_id],
      where: "is_avatar = true",
      name: :user_pictures_unique_avatar_per_user)
  end
end
