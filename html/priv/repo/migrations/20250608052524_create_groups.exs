defmodule Socialite.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :location, :geometry
      add :radius_km, :float, default: 10.0
      add :is_public, :boolean, default: true
      add :avatar_url, :string
      add :cover_url, :string
      add :member_count, :integer, default: 0
      add :creator_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:groups, [:creator_id])
    create index(:groups, [:location], using: :gist)
    create index(:groups, [:is_public])
  end
end
