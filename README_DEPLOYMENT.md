# Deployment Guide - Image Upload Fix

## Problem
Images uploaded in production on Fly.io return 404 errors because:
1. Files are stored in the local filesystem (`priv/static/uploads/`)
2. Fly.io containers have ephemeral filesystems
3. When containers restart, uploaded files are lost

## Solution 1: Fly.io Volumes (Current Implementation)

### What was changed:
1. **fly.toml**: Added volume mount configuration
2. **endpoint.ex**: Updated to serve files from `/app/uploads` in production
3. **settings_live.ex**: Updated upload path for production
4. **deploy.sh**: Script to create volume and deploy

### To deploy:
```bash
# Make script executable (already done)
chmod +x deploy.sh

# Deploy with volume
./deploy.sh
```

### Manual deployment:
```bash
# Create volume (1GB)
fly volumes create uploads_data --region waw --size 1

# Deploy app
fly deploy
```

## Solution 2: Cloud Storage (Recommended)

For better scalability and reliability, consider using cloud storage:

### AWS S3 Setup:
1. Add dependencies to `mix.exs`:
```elixir
{:ex_aws, "~> 2.1"},
{:ex_aws_s3, "~> 2.0"},
{:hackney, "~> 1.9"}
```

2. Configure in `config/runtime.exs`:
```elixir
config :ex_aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: "us-east-1"
```

3. Set Fly.io secrets:
```bash
fly secrets set AWS_ACCESS_KEY_ID=your_key
fly secrets set AWS_SECRET_ACCESS_KEY=your_secret
```

### Cloudflare R2 Setup (Cheaper):
1. Same dependencies as S3
2. Configure endpoint:
```elixir
config :ex_aws, :s3,
  scheme: "https://",
  host: "your-account-id.r2.cloudflarestorage.com",
  region: "auto"
```

## Current Status
✅ Volume-based solution implemented and ready to deploy
⚠️ Cloud storage solution requires additional setup

## Testing
After deployment, test image uploads:
1. Go to Settings page
2. Upload a profile picture
3. Verify image displays correctly
4. Restart the app and verify image persists

## Troubleshooting
- Check volume is mounted: `fly ssh console` then `ls -la /app/uploads`
- Check logs: `fly logs`
- Verify volume exists: `fly volumes list` 