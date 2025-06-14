defmodule Socialite.Repo.Migrations.AddLocationToUsers do
  use Ecto.Migration

  def up do
    # Enable PostGIS extension if not already enabled
    execute "CREATE EXTENSION IF NOT EXISTS postgis"

    alter table(:users) do
      add :latitude, :float
      add :longitude, :float
      add :address, :string
      add :city, :string
      add :state, :string
      add :country, :string
      add :postal_code, :string
      add :location_point, :geometry
    end

    # Create indexes for location-based queries
    create index(:users, [:latitude, :longitude])
    execute "CREATE INDEX users_location_point_idx ON users USING gist (location_point)"
  end

  def down do
    alter table(:users) do
      remove :latitude
      remove :longitude
      remove :address
      remove :city
      remove :state
      remove :country
      remove :postal_code
      remove :location_point
    end
  end
end
