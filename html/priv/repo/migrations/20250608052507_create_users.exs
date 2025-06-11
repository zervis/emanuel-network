defmodule Socialite.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS postgis"

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :username, :string, null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :bio, :text
      add :avatar_url, :string
      add :cover_url, :string
      add :password_hash, :string, null: false
      add :confirmed_at, :naive_datetime
      add :location, :geometry
      add :kudos_count, :integer, default: 0
      add :daily_kudos, :integer, default: 100
      add :last_kudos_reset, :date
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
    create index(:users, [:location], using: :gist)
  end

  def down do
    drop table(:users)
  end
end
