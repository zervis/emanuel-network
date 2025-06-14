defmodule Socialite.Repo do
  use Ecto.Repo,
    otp_app: :socialite,
    adapter: Ecto.Adapters.Postgres

  # PostGIS setup
  def after_connect(conn) do
    Postgrex.query!(conn, "CREATE EXTENSION IF NOT EXISTS postgis", [])
  end
end
