defmodule Socialite.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :gender, :string
      add :relationship_status, :string
      add :personality_type, :string
      add :birthdate, :date
    end

    # Create an index for birthdate to optimize age-based queries
    create index(:users, [:birthdate])
  end
end
