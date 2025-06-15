defmodule Mix.Tasks.TestTigris do
  @moduledoc """
  Test Tigris storage connection and configuration.

  Usage:
    mix test_tigris
  """

  use Mix.Task

  @shortdoc "Test Tigris storage connection"

  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("🐅 Testing Tigris Storage Configuration...")
    IO.puts("=" |> String.duplicate(50))

    # Check configuration
    config = Application.get_env(:socialite, :file_storage, [])
    adapter = Keyword.get(config, :adapter, :local)

    IO.puts("📋 Current Configuration:")
    IO.puts("  Adapter: #{adapter}")
    IO.puts("  Bucket: #{Keyword.get(config, :bucket, "not set")}")
    IO.puts("  Region: #{Keyword.get(config, :region, "not set")}")
    IO.puts("  Endpoint: #{Keyword.get(config, :endpoint, "not set")}")

    case adapter do
      :local ->
        test_local_storage(config)
      :s3 ->
        test_tigris_storage(config)
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
    test_content = "Tigris test file - #{DateTime.utc_now()}"

    try do
      File.write!(test_file, test_content)
      content = File.read!(test_file)
      File.rm!(test_file)

      if content == test_content do
        IO.puts("✅ Local storage is working correctly")
        IO.puts("   Path: #{Path.expand(local_path)}")
      else
        IO.puts("❌ Local storage test failed - content mismatch")
      end
    rescue
      e ->
        IO.puts("❌ Local storage test failed: #{Exception.message(e)}")
    end
  end

  defp test_tigris_storage(config) do
    IO.puts("\n🐅 Testing Tigris Storage...")

    # Check environment variables
    access_key = System.get_env("TIGRIS_ACCESS_KEY_ID") || System.get_env("AWS_ACCESS_KEY_ID")
    secret_key = System.get_env("TIGRIS_SECRET_ACCESS_KEY") || System.get_env("AWS_SECRET_ACCESS_KEY")
    bucket = Keyword.get(config, :bucket)

    IO.puts("🔑 Credentials Check:")
    IO.puts("  Access Key: #{if access_key, do: "✅ Set (#{String.slice(access_key, 0..7)}...)", else: "❌ Not set"}")
    IO.puts("  Secret Key: #{if secret_key, do: "✅ Set", else: "❌ Not set"}")
    IO.puts("  Bucket: #{bucket}")

    if access_key && secret_key do
      test_tigris_connection(bucket)
    else
      IO.puts("\n❌ Missing Tigris credentials!")
      IO.puts("   Set TIGRIS_ACCESS_KEY_ID and TIGRIS_SECRET_ACCESS_KEY environment variables")
      print_tigris_setup_instructions()
    end
  end

  defp test_tigris_connection(bucket) do
    IO.puts("\n🔗 Testing Tigris Connection...")

    try do
      # Test bucket listing
      case ExAws.S3.list_buckets() |> ExAws.request() do
        {:ok, %{body: %{buckets: buckets}}} ->
          IO.puts("✅ Successfully connected to Tigris!")
          IO.puts("   Available buckets: #{length(buckets)}")

          bucket_names = Enum.map(buckets, & &1.name)
          if bucket in bucket_names do
            IO.puts("✅ Target bucket '#{bucket}' exists")
            test_file_operations(bucket)
          else
            IO.puts("⚠️  Target bucket '#{bucket}' not found")
            IO.puts("   Available buckets: #{Enum.join(bucket_names, ", ")}")
            IO.puts("   You may need to create the bucket first")
          end

        {:error, error} ->
          IO.puts("❌ Failed to connect to Tigris: #{inspect(error)}")
          print_tigris_troubleshooting()
      end
    rescue
      e ->
        IO.puts("❌ Connection test failed: #{Exception.message(e)}")
        print_tigris_troubleshooting()
    end
  end

  defp test_file_operations(bucket) do
    IO.puts("\n📄 Testing File Operations...")

    test_key = "test/tigris_test_#{:os.system_time(:millisecond)}.txt"
    test_content = "Hello from Tigris! #{DateTime.utc_now()}"

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
                IO.puts("\n🎉 All Tigris tests passed!")
              else
                IO.puts("❌ Downloaded content doesn't match uploaded content")
              end

            {:error, error} ->
              IO.puts("❌ File download failed: #{inspect(error)}")
          end

        {:error, error} ->
          IO.puts("❌ File upload failed: #{inspect(error)}")
      end
    rescue
      e ->
        IO.puts("❌ File operations test failed: #{Exception.message(e)}")
    end
  end

  defp print_tigris_setup_instructions do
    IO.puts("\n📚 Tigris Setup Instructions:")
    IO.puts("=" |> String.duplicate(50))
    IO.puts("1. Sign up at https://www.tigrisdata.com/")
    IO.puts("2. Create a new project")
    IO.puts("3. Generate API credentials")
    IO.puts("4. Set environment variables:")
    IO.puts("   export TIGRIS_ACCESS_KEY_ID=\"your_access_key\"")
    IO.puts("   export TIGRIS_SECRET_ACCESS_KEY=\"your_secret_key\"")
    IO.puts("   export TIGRIS_BUCKET_NAME=\"your_bucket_name\"")
    IO.puts("5. Create a bucket in your Tigris dashboard")
    IO.puts("6. Run this test again: mix test_tigris")
  end

  defp print_tigris_troubleshooting do
    IO.puts("\n🔧 Troubleshooting:")
    IO.puts("- Verify your credentials are correct")
    IO.puts("- Check if your bucket exists in Tigris dashboard")
    IO.puts("- Ensure your network allows HTTPS connections")
    IO.puts("- Try creating the bucket if it doesn't exist")
  end
end
