import Config

# Tigiris Production Configuration
# This file contains production-specific settings for Tigiris deployment

# Database configuration for production
config :socialite, Socialite.Repo,
  # Use environment variables for database connection
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: true,
  ssl_opts: [verify: :verify_none]

# Endpoint configuration for production
config :socialite, SocialiteWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "tigiris.com", port: 443, scheme: "https"],
  http: [
    # Enable IPv6 and bind on all interfaces.
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000")
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  server: true

# S3 Configuration for Tigiris Production
# Configure ExAws for Tigris
config :ex_aws,
  access_key_id: System.get_env("TIGRIS_ACCESS_KEY_ID") || raise("TIGRIS_ACCESS_KEY_ID not set"),
  secret_access_key: System.get_env("TIGRIS_SECRET_ACCESS_KEY") || raise("TIGRIS_SECRET_ACCESS_KEY not set"),
  json_codec: Jason,
  debug_requests: false

config :ex_aws, :s3,
  scheme: "https://",
  host: "fly.storage.tigris.dev",
  region: "auto"

# File storage configuration for Tigris
config :socialite, :file_storage,
  adapter: :s3,
  bucket: System.get_env("TIGRIS_BUCKET_NAME") || "socialite-production",
  region: "auto",
  endpoint: "https://fly.storage.tigris.dev"

# Mailer configuration for production
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  port: 587,
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  tls: :if_available,
  allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
  ssl: false,
  retries: 1,
  no_mx_lookups: false,
  auth: :always

# SSL configuration
config :socialite, SocialiteWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]]

# Logger configuration for production
config :logger, level: :info

# Runtime production config
if System.get_env("PHX_SERVER") do
  config :socialite, SocialiteWeb.Endpoint, server: true
end

# Disable Swoosh Local Memory Storage in production
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Configure Finch for HTTP requests
config :socialite, :finch_name, Socialite.Finch
