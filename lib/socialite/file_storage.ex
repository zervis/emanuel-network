defmodule Socialite.FileStorage do
  @moduledoc """
  File storage abstraction that works with both local storage and Tigris (S3-compatible).

  This module provides a unified interface for file operations regardless of the
  underlying storage backend (local filesystem or Tigris object storage).
  """

  require Logger

  @doc """
  Upload a file to the configured storage backend.

  ## Parameters
  - `file_path`: Local path to the file to upload
  - `key`: Storage key/path for the file
  - `opts`: Additional options (content_type, etc.)

  ## Returns
  - `{:ok, url}` on success
  - `{:error, reason}` on failure
  """
  def upload_file(file_path, key, opts \\ []) do
    case get_adapter() do
      :local -> upload_local(file_path, key, opts)
      :s3 -> upload_s3(file_path, key, opts)
    end
  end

  @doc """
  Upload file content directly to storage.

  ## Parameters
  - `content`: Binary content to upload
  - `key`: Storage key/path for the file
  - `opts`: Additional options (content_type, etc.)
  """
  def upload_content(content, key, opts \\ []) do
    case get_adapter() do
      :local -> upload_content_local(content, key, opts)
      :s3 -> upload_content_s3(content, key, opts)
    end
  end

  @doc """
  Delete a file from storage.
  """
  def delete_file(key) do
    case get_adapter() do
      :local -> delete_local(key)
      :s3 -> delete_s3(key)
    end
  end

  @doc """
  Get the public URL for a file.
  """
  def get_url(key) do
    case get_adapter() do
      :local -> get_local_url(key)
      :s3 -> get_s3_url(key)
    end
  end

  @doc """
  Generate a signed URL for private file access (S3 only).
  """
  def get_signed_url(key, expires_in \\ 3600) do
    case get_adapter() do
      :local -> get_local_url(key)  # Local files are always public
      :s3 -> get_s3_signed_url(key, expires_in)
    end
  end

  # Private functions

  defp get_adapter do
    config = Application.get_env(:socialite, :file_storage, [])
    Keyword.get(config, :adapter, :local)
  end

  defp get_config do
    Application.get_env(:socialite, :file_storage, [])
  end

  # Local storage implementation

  defp upload_local(file_path, key, _opts) do
    config = get_config()
    local_path = Keyword.get(config, :local_path, "priv/static/uploads")

    destination = Path.join(local_path, key)
    destination_dir = Path.dirname(destination)

    with :ok <- File.mkdir_p(destination_dir),
         {:ok, _} <- File.copy(file_path, destination) do
      url = get_local_url(key)
      Logger.info("File uploaded to local storage: #{key}")
      {:ok, url}
    else
      error ->
        Logger.error("Failed to upload file to local storage: #{inspect(error)}")
        {:error, error}
    end
  end

  defp upload_content_local(content, key, _opts) do
    config = get_config()
    local_path = Keyword.get(config, :local_path, "priv/static/uploads")

    destination = Path.join(local_path, key)
    destination_dir = Path.dirname(destination)

    with :ok <- File.mkdir_p(destination_dir),
         :ok <- File.write(destination, content) do
      url = get_local_url(key)
      Logger.info("Content uploaded to local storage: #{key}")
      {:ok, url}
    else
      error ->
        Logger.error("Failed to upload content to local storage: #{inspect(error)}")
        {:error, error}
    end
  end

  defp delete_local(key) do
    config = get_config()
    local_path = Keyword.get(config, :local_path, "priv/static/uploads")
    file_path = Path.join(local_path, key)

    case File.rm(file_path) do
      :ok ->
        Logger.info("File deleted from local storage: #{key}")
        :ok
      {:error, :enoent} ->
        Logger.warn("File not found for deletion: #{key}")
        :ok  # Consider missing file as successful deletion
      error ->
        Logger.error("Failed to delete file from local storage: #{inspect(error)}")
        error
    end
  end

  defp get_local_url(key) do
    # Assuming files are served from /uploads/ route
    "/uploads/#{key}"
  end

  # S3/Tigris implementation

  defp upload_s3(file_path, key, opts) do
    bucket = get_bucket()
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    with {:ok, content} <- File.read(file_path) do
      upload_content_s3(content, key, [content_type: content_type])
    end
  end

  defp upload_content_s3(content, key, opts) do
    bucket = get_bucket()
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    request = ExAws.S3.put_object(bucket, key, content, [
      content_type: content_type,
      acl: :public_read
    ])

    case ExAws.request(request) do
      {:ok, _response} ->
        url = get_s3_url(key)
        Logger.info("File uploaded to Tigris: #{key}")
        {:ok, url}
      {:error, error} ->
        Logger.error("Failed to upload file to Tigris: #{inspect(error)}")
        {:error, error}
    end
  end

  defp delete_s3(key) do
    bucket = get_bucket()

    case ExAws.S3.delete_object(bucket, key) |> ExAws.request() do
      {:ok, _response} ->
        Logger.info("File deleted from Tigris: #{key}")
        :ok
      {:error, error} ->
        Logger.error("Failed to delete file from Tigris: #{inspect(error)}")
        {:error, error}
    end
  end

  defp get_s3_url(key) do
    config = get_config()
    bucket = get_bucket()
    endpoint = Keyword.get(config, :endpoint, "https://fly.storage.tigris.dev")

    "#{endpoint}/#{bucket}/#{key}"
  end

  defp get_s3_signed_url(key, expires_in) do
    bucket = get_bucket()

    case ExAws.S3.presigned_url(:get, bucket, key, expires_in: expires_in) do
      {:ok, url} -> url
      {:error, _} -> get_s3_url(key)  # Fallback to public URL
    end
  end

  defp get_bucket do
    config = get_config()
    Keyword.get(config, :bucket, "socialite-uploads")
  end

  # Utility functions

  @doc """
  Generate a unique filename with timestamp and random suffix.
  """
  def generate_filename(original_filename) do
    timestamp = :os.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    extension = Path.extname(original_filename)

    "#{timestamp}_#{random}#{extension}"
  end

  @doc """
  Get MIME type from file extension.
  """
  def get_content_type(filename) do
    case Path.extname(filename) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".pdf" -> "application/pdf"
      ".txt" -> "text/plain"
      ".html" -> "text/html"
      ".css" -> "text/css"
      ".js" -> "application/javascript"
      ".json" -> "application/json"
      _ -> "application/octet-stream"
    end
  end

  @doc """
  Validate file size and type.
  """
  def validate_file(file_path, opts \\ []) do
    max_size = Keyword.get(opts, :max_size, 10 * 1024 * 1024)  # 10MB default
    allowed_types = Keyword.get(opts, :allowed_types, :all)

    with {:ok, %{size: size}} <- File.stat(file_path),
         :ok <- validate_size(size, max_size),
         :ok <- validate_type(file_path, allowed_types) do
      :ok
    end
  end

  defp validate_size(size, max_size) when size <= max_size, do: :ok
  defp validate_size(size, max_size), do: {:error, "File too large: #{size} bytes (max: #{max_size})"}

  defp validate_type(_file_path, :all), do: :ok
  defp validate_type(file_path, allowed_types) when is_list(allowed_types) do
    extension = Path.extname(file_path) |> String.downcase()
    if extension in allowed_types do
      :ok
    else
      {:error, "File type not allowed: #{extension}"}
    end
  end
end
