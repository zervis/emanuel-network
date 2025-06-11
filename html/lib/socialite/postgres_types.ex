defmodule Socialite.PostgresTypes do
  Postgrex.Types.define(
    Socialite.PostgresTypes,
    [Geo.PostGIS.Extension] ++ Ecto.Adapters.Postgres.extensions(),
    json: Jason
  )
end
