import Config

# Configure your database
config :socialite, Socialite.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "socialite_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
# Binding to loopback ipv4 address prevents access from other machines.
config :socialite, SocialiteWeb.Endpoint,
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "bkW5fhZtpi+NPkb/3g1FDGD2rFLQna8Q6Odps6V/aKoHM7fAdU7s09teTdfSShmZ",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:socialite, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:socialite, ~w(--watch)]}
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :socialite, SocialiteWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/socialite_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :socialite, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Configure mailer for development with SMTP
# Using Gmail SMTP as example - replace with your email provider settings
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  port: 587,
  username: System.get_env("SMTP_USERNAME") || "emanuel.network.email@gmail.com",
  password: System.get_env("SMTP_PASSWORD") || "No1oczko!",
  tls: :if_available,
  allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
  ssl: false,
  retries: 1,
  no_mx_lookups: false,
  auth: :always

# Configure AWS S3 for development
# For local development without AWS credentials, files will be stored locally
# Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables to use S3
config :socialite, :file_storage,
  adapter: if(System.get_env("AWS_ACCESS_KEY_ID"), do: :s3, else: :local),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  bucket: System.get_env("AWS_S3_BUCKET") || "emanuel-network",
  region: System.get_env("AWS_REGION") || "auto",
  local_path: "priv/static/uploads"
