defmodule Socialite.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :avatar, :string
      add :bio, :text
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
