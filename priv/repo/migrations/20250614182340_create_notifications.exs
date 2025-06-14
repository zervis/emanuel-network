defmodule Socialite.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :type, :string, null: false
      add :message, :text, null: false
      add :read_at, :utc_datetime
      add :data, :map, default: %{}
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :actor_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:actor_id])
    create index(:notifications, [:user_id, :read_at])
    create index(:notifications, [:type])
  end
end
