defmodule SocialiteWeb.SettingsLive do
  use SocialiteWeb, :live_view
  alias Socialite.Accounts
  alias Socialite.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    current_user_id = session["current_user_id"]

    if current_user_id do
      case Socialite.Repo.get(User, current_user_id) do
        %User{} = user ->
          changeset = Accounts.change_user_profile(user, %{})
          user_pictures = Accounts.list_user_pictures(user.id)
          picture_count = Accounts.count_user_pictures(user.id)

          {:ok,
           socket
           |> assign(:user, user)
           |> assign(:changeset, changeset)
           |> assign(:user_pictures, user_pictures)
           |> assign(:picture_count, picture_count)
           |> assign(:uploaded_files, [])
           |> allow_upload(:picture,
               accept: ~w(.jpg .jpeg .png .gif .webp),
               max_entries: 1,
               max_file_size: 5_000_000,
               auto_upload: true,
               progress: &handle_progress/3)}  # 5MB limit
        nil ->
          {:ok,
           socket
           |> put_flash(:error, "You must be logged in to access settings.")
           |> redirect(to: "/")}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to access settings.")
       |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    # Process height and weight parameters to handle empty strings
    processed_params = user_params
    |> process_height_weight()

    changeset =
      socket.assigns.user
      |> Accounts.change_user_profile(processed_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    # Process height and weight parameters to handle empty strings
    processed_params = user_params
    |> process_height_weight()

    case Accounts.update_user_profile(socket.assigns.user, processed_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully")
         |> assign(:user, user)
         |> assign(:changeset, Accounts.change_user_profile(user, %{}))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  # Helper function to process height and weight parameters
  defp process_height_weight(params) do
    params
    |> process_height()
    |> process_weight()
  end

  defp process_height(%{"height" => height} = params) when height in ["", nil] do
    Map.put(params, "height", nil)
  end

  defp process_height(%{"height" => height} = params) when is_binary(height) do
    case Integer.parse(height) do
      {int_height, ""} -> Map.put(params, "height", int_height)
      _ -> Map.put(params, "height", nil)
    end
  end

  defp process_height(params), do: params

  defp process_weight(%{"weight" => weight} = params) when weight in ["", nil] do
    Map.put(params, "weight", nil)
  end

  defp process_weight(%{"weight" => weight} = params) when is_binary(weight) do
    case Float.parse(weight) do
      {float_weight, ""} -> Map.put(params, "weight", float_weight)
      _ -> Map.put(params, "weight", nil)
    end
  end

  defp process_weight(params), do: params



  @impl true
  def handle_event("set_location", %{"latitude" => lat, "longitude" => lng}, socket) do
    case Accounts.update_user_location(socket.assigns.user, %{
           latitude: lat,
           longitude: lng
         }) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Location updated successfully")
         |> assign(:user, user)
         |> assign(:changeset, Accounts.change_user_profile(user, %{}))
         |> assign(:location_loading, false)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update location")
         |> assign(:location_loading, false)}
    end
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    IO.puts("=== VALIDATE_UPLOAD EVENT ===")
    IO.puts("Upload entries: #{length(socket.assigns.uploads.picture.entries)}")

    Enum.each(socket.assigns.uploads.picture.entries, fn entry ->
      IO.puts("Entry: #{entry.client_name}")
      IO.puts("Progress: #{entry.progress}%")
      IO.puts("Valid: #{entry.valid?}")
      IO.puts("Done: #{entry.done?}")
    end)

    upload_errors = upload_errors(socket.assigns.uploads.picture)
    IO.puts("Upload errors: #{inspect(upload_errors)}")

    # This event is triggered during file upload validation
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :picture, ref)}
  end

  # Handle upload progress updates
  def handle_progress(:picture, entry, socket) do
    IO.puts("=== UPLOAD PROGRESS ===")
    IO.puts("Entry: #{entry.client_name}")
    IO.puts("Progress: #{entry.progress}%")
    IO.puts("Done: #{entry.done?}")

    if entry.done? do
      IO.puts("Upload completed for #{entry.client_name}")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_picture", _params, socket) do
    user_id = socket.assigns.user.id
    picture_count = socket.assigns.picture_count

    if picture_count >= 6 do
      {:noreply, put_flash(socket, :error, "You can only have up to 6 pictures")}
    else
      uploaded_files =
        consume_uploaded_entries(socket, :picture, fn %{path: path}, entry ->
          # Generate a unique filename with proper extension
          extension = Path.extname(entry.client_name)
          filename = "#{user_id}_#{System.system_time(:millisecond)}_#{:rand.uniform(1000)}#{extension}"

          # Use different paths for development vs production
          dest_path = if Mix.env() == :prod do
            Path.join(["/app/uploads", filename])
          else
            Path.join(["priv", "static", "uploads", filename])
          end

          # Ensure the uploads directory exists
          File.mkdir_p!(Path.dirname(dest_path))

          # Copy the uploaded file to the destination
          case File.cp(path, dest_path) do
            :ok ->
              # Return the URL path for the uploaded file
              "/uploads/#{filename}"
            {:error, reason} ->
              raise "Failed to save file: #{reason}"
          end
        end)

      case uploaded_files do
        [url] when is_binary(url) ->
          case Accounts.create_user_picture(%{
                 url: url,
                 user_id: user_id,
                 order: picture_count
               }) do
            {:ok, _picture} ->
              user_pictures = Accounts.list_user_pictures(user_id)
              picture_count = Accounts.count_user_pictures(user_id)

              {:noreply,
               socket
               |> put_flash(:info, "Picture uploaded successfully")
               |> assign(:user_pictures, user_pictures)
               |> assign(:picture_count, picture_count)}

            {:error, changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to save picture: #{inspect(changeset.errors)}")}
          end

        [] ->
          {:noreply, put_flash(socket, :error, "No file was uploaded")}

        _other ->
          {:noreply, put_flash(socket, :error, "Upload failed")}
      end
    end
  end

  @impl true
  def handle_event("set_avatar", %{"picture_id" => picture_id}, socket) do
    user_id = socket.assigns.user.id

    case Accounts.set_avatar_picture(user_id, String.to_integer(picture_id)) do
      {:ok, _} ->
        user_pictures = Accounts.list_user_pictures(user_id)
        # Reload user data to update avatar in header
        updated_user = Accounts.get_user!(user_id)

        {:noreply,
         socket
         |> put_flash(:info, "Avatar updated successfully")
         |> assign(:user_pictures, user_pictures)
         |> assign(:user, updated_user)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update avatar")}
    end
  end

  @impl true
  def handle_event("delete_picture", %{"picture_id" => picture_id}, socket) do
    user_id = socket.assigns.user.id

    case Accounts.delete_user_picture(user_id, String.to_integer(picture_id)) do
      {:ok, deleted_picture} ->
        # Delete the file from the filesystem
        file_path = if Mix.env() == :prod do
          Path.join(["/app", deleted_picture.url])
        else
          Path.join(["priv", "static", deleted_picture.url])
        end
        File.rm(file_path)

        user_pictures = Accounts.list_user_pictures(user_id)
        picture_count = Accounts.count_user_pictures(user_id)

        {:noreply,
         socket
         |> put_flash(:info, "Picture deleted successfully")
         |> assign(:user_pictures, user_pictures)
         |> assign(:picture_count, picture_count)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete picture")}
    end
  end

  # Helper function to convert upload errors to readable strings
  defp error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end
