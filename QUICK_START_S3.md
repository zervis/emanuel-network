# Quick Start: Testing S3 Configuration

## 1. Set Environment Variables

For development, you can set these in your shell:

```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_REGION="us-east-1"
export AWS_S3_BUCKET="your-bucket-name"
```

## 2. Test S3 Connection

Run the built-in test task:

```bash
mix test_s3
```

This will:
- Show your current configuration
- Test connection to S3
- Upload a test file
- Download the test file
- Delete the test file

## 3. Switch Between Local and S3 Storage

### Use S3 Storage
In `config/dev.exs`, set:
```elixir
config :socialite, :file_storage,
  adapter: :s3,
  bucket: System.get_env("AWS_S3_BUCKET") || "socialite-dev-uploads",
  region: System.get_env("AWS_REGION") || "us-east-1"
```

### Use Local Storage (Fallback)
In `config/dev.exs`, set:
```elixir
config :socialite, :file_storage,
  adapter: :local
```

## 4. Test File Upload in Application

1. Start the server: `mix phx.server`
2. Go to Settings page
3. Upload a profile picture
4. Check your S3 bucket for the uploaded file

## 5. Manual Testing in IEx

```elixir
# Start IEx
iex -S mix

# Test the FileUpload service
{:ok, url} = Socialite.FileUpload.upload_file("/path/to/test/file.jpg", "test.jpg", "image/jpeg")

# Delete the file
:ok = Socialite.FileUpload.delete_file(url)
```

## Troubleshooting

If uploads fail, check:
1. AWS credentials are set correctly
2. Bucket exists and is accessible
3. IAM permissions are correct
4. Region matches your bucket's region

Run `mix test_s3` for detailed error messages. 