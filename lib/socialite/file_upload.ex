defmodule Socialite.FileUpload do
  @moduledoc """
  Service for handling file uploads to S3 or local storage.
  """

  alias ExAws.S3

  @doc """
  Uploads a file to the configured storage backend.
  Returns {:ok, url} on success or {:error, reason} on failure.
  """
  def upload_file(file_path, filename, content_type \\ "image/jpeg") do
    case get_storage_config() do
      %{adapter: :s3} = config ->
        upload_to_s3(file_path, filename, content_type, config)
      %{adapter: :local} ->
        upload_to_local(file_path, filename)
    end
  end

  @doc """
  Deletes a file from the configured storage backend.
  """
  def delete_file(file_url) do
    case get_storage_config() do
      %{adapter: :s3} = config ->
        delete_from_s3(file_url, config)
      %{adapter: :local} ->
        delete_from_local(file_url)
    end
  end

  @doc """
  Generates a unique filename with the given extension.
  """
  def generate_filename(user_id, extension) do
    timestamp = System.system_time(:millisecond)
    random = :rand.uniform(1000)
    "#{user_id}_#{timestamp}_#{random}#{extension}"
  end

  @doc """
  Gets the file extension from a filename.
  """
  def get_extension(filename) do
    Path.extname(filename)
  end

  @doc """
  Determines content type from file extension.
  """
  def get_content_type(extension) do
    case String.downcase(extension) do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      _ -> "application/octet-stream"
    end
  end

  # Private functions

  defp get_storage_config do
    Application.get_env(:socialite, :file_storage, %{adapter: :local})
  end

  defp upload_to_s3(file_path, filename, content_type, config) do
    bucket = config[:bucket]
    key = "uploads/#{filename}"

    case File.read(file_path) do
      {:ok, file_binary} ->
        request = S3.put_object(bucket, key, file_binary, [
          content_type: content_type,
          acl: :public_read
        ])

        case ExAws.request(request) do
          {:ok, _response} ->
            url = "https://#{bucket}.s3.amazonaws.com/#{key}"
            {:ok, url}
          {:error, reason} ->
            {:error, "S3 upload failed: #{inspect(reason)}"}
        end
      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  defp upload_to_local(file_path, filename) do
    # Use different paths for development vs production
    dest_path = if Mix.env() == :prod do
      Path.join(["/app/uploads", filename])
    else
      Path.join(["priv", "static", "uploads", filename])
    end

    # Ensure the uploads directory exists
    File.mkdir_p!(Path.dirname(dest_path))

    # Copy the uploaded file to the destination
    case File.cp(file_path, dest_path) do
      :ok ->
        {:ok, "/uploads/#{filename}"}
      {:error, reason} ->
        {:error, "Failed to save file: #{reason}"}
    end
  end

  defp delete_from_s3(file_url, config) do
    bucket = config[:bucket]

    # Extract the key from the URL
    case extract_s3_key_from_url(file_url, bucket) do
      {:ok, key} ->
        request = S3.delete_object(bucket, key)
        case ExAws.request(request) do
          {:ok, _response} -> :ok
          {:error, reason} -> {:error, "S3 delete failed: #{inspect(reason)}"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete_from_local(file_url) do
    # Extract filename from URL
    filename = Path.basename(file_url)

    file_path = if Mix.env() == :prod do
      Path.join(["/app/uploads", filename])
    else
      Path.join(["priv", "static", "uploads", filename])
    end

    case File.rm(file_path) do
      :ok -> :ok
      {:error, :enoent} -> :ok  # File doesn't exist, consider it deleted
      {:error, reason} -> {:error, "Failed to delete file: #{reason}"}
    end
  end

  defp extract_s3_key_from_url(url, bucket) do
    # Handle both formats:
    # https://bucket.s3.amazonaws.com/uploads/filename
    # https://s3.amazonaws.com/bucket/uploads/filename
    cond do
      String.contains?(url, "#{bucket}.s3.amazonaws.com/") ->
        key = url |> String.split("#{bucket}.s3.amazonaws.com/") |> List.last()
        {:ok, key}
      String.contains?(url, "s3.amazonaws.com/#{bucket}/") ->
        key = url |> String.split("s3.amazonaws.com/#{bucket}/") |> List.last()
        {:ok, key}
      true ->
        {:error, "Invalid S3 URL format"}
    end
  end
end
