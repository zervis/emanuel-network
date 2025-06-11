defmodule Socialite.Repo.Migrations.CreateKudos do
  use Ecto.Migration

  def change do
    create table(:kudos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message, :text
      add :giver_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :receiver_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:kudos, [:giver_id])
    create index(:kudos, [:receiver_id])
    create index(:kudos, [:inserted_at])

    # Unique constraint to ensure one kudo per day per giver-receiver pair
    create unique_index(:kudos, [:giver_id, :receiver_id, "date(inserted_at)"],
           name: :kudos_giver_id_receiver_id_date_index)
  end
end
