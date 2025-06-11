defmodule Socialite.Repo do
  use Ecto.Repo,
    otp_app: :socialite,
    adapter: Ecto.Adapters.Postgres
end
