defmodule Socialite.Repo.Migrations.CreateKudosTable do
  use Ecto.Migration

  def change do
    create table(:kudos) do
      add :giver_id, references(:users, on_delete: :delete_all), null: false
      add :receiver_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:kudos, [:giver_id])
    create index(:kudos, [:receiver_id])
    create unique_index(:kudos, [:giver_id, :receiver_id])
  end
end
