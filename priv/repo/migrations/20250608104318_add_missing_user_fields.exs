defmodule Socialite.Repo.Migrations.AddMissingUserFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists :bio, :text
      add_if_not_exists :is_active, :boolean, default: true
      add_if_not_exists :daily_kudos_credits, :integer, default: 100
      add_if_not_exists :last_credits_reset, :date
    end
  end
end
