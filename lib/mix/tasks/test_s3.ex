defmodule Mix.Tasks.TestS3 do
  @moduledoc """
  Test AWS S3 storage connection and configuration.

  Usage:
    mix test_s3
  """

  use Mix.Task

  @shortdoc "Test AWS S3 storage connection"

  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("🚀 Testing AWS S3 Storage Configuration...")
    IO.puts("=" |> String.duplicate(50))

    # Check configuration
    config = Application.get_env(:socialite, :file_storage, [])
    adapter = Keyword.get(config, :adapter, :local)

    IO.puts("📋 Current Configuration:")
    IO.puts("  Adapter: #{adapter}")
    IO.puts("  Bucket: #{Keyword.get(config, :bucket, "not set")}")
    IO.puts("  Region: #{Keyword.get(config, :region, "not set")}")

    case adapter do
      :local ->
        test_local_storage(config)
      :s3 ->
        test_s3_storage(config)
      _ ->
        IO.puts("❌ Unknown adapter: #{adapter}")
    end
  end

  defp test_local_storage(config) do
    local_path = Keyword.get(config, :local_path, "priv/static/uploads")

    IO.puts("\n📁 Testing Local Storage...")

    # Ensure directory exists
    File.mkdir_p!(local_path)

    # Test file operations
    test_file = Path.join(local_path, "test_#{:os.system_time(:millisecond)}.txt")
    test_content = "S3 test file - #{DateTime.utc_now()}"

    try do
      File.write!(test_file, test_content)
      content = File.read!(test_file)
      File.rm!(test_file)

      if content == test_content do
        IO.puts("✅ Local storage is configured (no S3 test needed)")
        IO.puts("   Path: #{Path.expand(local_path)}")
        IO.puts("   💡 Set AWS_ACCESS_KEY_ID to enable S3 storage")
      else
        IO.puts("❌ Local storage test failed - content mismatch")
      end
    rescue
      e ->
        IO.puts("❌ Local storage test failed: #{Exception.message(e)}")
    end
  end

  defp test_s3_storage(config) do
    IO.puts("\n☁️  Testing AWS S3 Storage...")

    # Check environment variables
    access_key = System.get_env("AWS_ACCESS_KEY_ID")
    secret_key = System.get_env("AWS_SECRET_ACCESS_KEY")
    region = System.get_env("AWS_REGION") || Keyword.get(config, :region, "eu-north-1")
    bucket = Keyword.get(config, :bucket)

    IO.puts("🔑 Credentials Check:")
    IO.puts("  Access Key: #{if access_key, do: "✅ Set (#{String.slice(access_key, 0..7)}...)", else: "❌ Not set"}")
    IO.puts("  Secret Key: #{if secret_key, do: "✅ Set", else: "❌ Not set"}")
    IO.puts("  Region: #{region}")
    IO.puts("  Bucket: #{bucket}")

    if access_key && secret_key do
      test_s3_connection(bucket, region)
    else
      IO.puts("\n❌ Missing AWS credentials!")
      IO.puts("   Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables")
      print_s3_setup_instructions()
    end
  end

  defp test_s3_connection(bucket, region) do
    IO.puts("\n🔗 Testing AWS S3 Connection...")

    try do
      # Test bucket access
      case ExAws.S3.head_bucket(bucket) |> ExAws.request() do
        {:ok, _} ->
          IO.puts("✅ Successfully connected to S3!")
          IO.puts("   Bucket '#{bucket}' is accessible")
          test_file_operations(bucket)

        {:error, {:http_error, 404, _}} ->
          IO.puts("❌ Bucket '#{bucket}' not found")
          IO.puts("   You need to create this bucket in AWS S3 console")
          print_bucket_creation_instructions(bucket, region)

        {:error, {:http_error, 403, _}} ->
          IO.puts("❌ Access denied to bucket '#{bucket}'")
          IO.puts("   Check your IAM permissions")
          print_iam_permissions()

        {:error, error} ->
          IO.puts("❌ Failed to connect to S3: #{inspect(error)}")
          print_s3_troubleshooting()
      end
    rescue
      e ->
        IO.puts("❌ Connection test failed: #{Exception.message(e)}")
        print_s3_troubleshooting()
    end
  end

  defp test_file_operations(bucket) do
    IO.puts("\n📄 Testing File Operations...")

    test_key = "test/s3_test_#{:os.system_time(:millisecond)}.txt"
    test_content = "Hello from AWS S3! #{DateTime.utc_now()}"

    try do
      # Upload test file
      case ExAws.S3.put_object(bucket, test_key, test_content) |> ExAws.request() do
        {:ok, _} ->
          IO.puts("✅ File upload successful")

          # Download test file
          case ExAws.S3.get_object(bucket, test_key) |> ExAws.request() do
            {:ok, %{body: downloaded_content}} ->
              if downloaded_content == test_content do
                IO.puts("✅ File download successful")

                # Clean up test file
                ExAws.S3.delete_object(bucket, test_key) |> ExAws.request()
                IO.puts("✅ File cleanup successful")
                IO.puts("\n🎉 All AWS S3 tests passed!")
              else
                IO.puts("❌ Downloaded content doesn't match uploaded content")
              end

            {:error, error} ->
              IO.puts("❌ File download failed: #{inspect(error)}")
          end

        {:error, error} ->
          IO.puts("❌ File upload failed: #{inspect(error)}")
          print_iam_permissions()
      end
    rescue
      e ->
        IO.puts("❌ File operations test failed: #{Exception.message(e)}")
    end
  end

  defp print_s3_setup_instructions do
    IO.puts("\n📚 AWS S3 Setup Instructions:")
    IO.puts("=" |> String.duplicate(50))
    IO.puts("1. Create an AWS account at https://aws.amazon.com/")
    IO.puts("2. Go to IAM console and create a new user")
    IO.puts("3. Attach S3 permissions to the user")
    IO.puts("4. Generate access keys for the user")
    IO.puts("5. Set environment variables:")
    IO.puts("   export AWS_ACCESS_KEY_ID=\"your_access_key\"")
    IO.puts("   export AWS_SECRET_ACCESS_KEY=\"your_secret_key\"")
    IO.puts("   export AWS_REGION=\"eu-north-1\"  # or your preferred region")
    IO.puts("   export AWS_S3_BUCKET=\"your_bucket_name\"")
    IO.puts("6. Create an S3 bucket in AWS console")
    IO.puts("7. Run this test again: mix test_s3")
  end

  defp print_bucket_creation_instructions(bucket, region) do
    IO.puts("\n🪣 Create S3 Bucket:")
    IO.puts("1. Go to AWS S3 Console: https://s3.console.aws.amazon.com/")
    IO.puts("2. Click 'Create bucket'")
    IO.puts("3. Bucket name: #{bucket}")
    IO.puts("4. Region: #{region}")
    IO.puts("5. Keep default settings and create the bucket")
  end

  defp print_iam_permissions do
    IO.puts("\n🔒 Required IAM Permissions:")
    IO.puts(~s({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }
  ]
}))
  end

  defp print_s3_troubleshooting do
    IO.puts("\n🔧 Troubleshooting:")
    IO.puts("- Verify your AWS credentials are correct")
    IO.puts("- Check if your bucket exists in AWS S3 console")
    IO.puts("- Ensure your IAM user has proper S3 permissions")
    IO.puts("- Verify the region matches your bucket's region")
    IO.puts("- Check AWS service status: https://status.aws.amazon.com/")
  end
end
