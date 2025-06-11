defmodule Socialite.Repo.Migrations.CreateGroupMemberships do
  use Ecto.Migration

  def change do
    create table(:group_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, default: "member"
      add :joined_at, :naive_datetime
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :group_id, references(:groups, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:group_memberships, [:user_id])
    create index(:group_memberships, [:group_id])
    create unique_index(:group_memberships, [:user_id, :group_id])
  end
end
