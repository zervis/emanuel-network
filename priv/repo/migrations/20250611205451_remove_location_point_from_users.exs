defmodule Socialite.Repo.Migrations.RemoveLocationPointFromUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :location_point
    end
  end

  def down do
    # Note: This down migration requires PostGIS to be properly configured
    # alter table(:users) do
    #   add :location_point, :geometry
    # end
    # For now, we'll leave this empty to avoid PostGIS configuration issues
  end
end
