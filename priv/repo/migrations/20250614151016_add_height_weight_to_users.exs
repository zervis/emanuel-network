defmodule Socialite.Repo.Migrations.AddHeightWeightToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :height, :integer  # Height in centimeters
      add :weight, :float    # Weight in kilograms
    end
  end
end
