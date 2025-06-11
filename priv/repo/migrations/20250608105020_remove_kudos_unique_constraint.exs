defmodule Socialite.Repo.Migrations.RemoveKudosUniqueConstraint do
  use Ecto.Migration

  def change do
    # Add amount field if it doesn't exist
    alter table(:kudos) do
      add_if_not_exists :amount, :integer, default: 1
    end

    # Remove the unique constraint if it exists
    drop_if_exists unique_index(:kudos, [:giver_id, :receiver_id])
  end
end
