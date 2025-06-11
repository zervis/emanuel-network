import Config

# Configure your database
config :socialite, Socialite.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "socialite_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  types: Socialite.PostgresTypes
