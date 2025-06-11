defmodule Socialite.Repo.Migrations.AddKudosToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :kudos_count, :integer, default: 0
    end
  end
end
