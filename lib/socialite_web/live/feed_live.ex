defmodule SocialiteWeb.FeedLive do
  use SocialiteWeb, :live_view
  import Ecto.Query

  alias Socialite.{Content, Accounts, Groups, User}

  @impl true
  def mount(_params, session, socket) do
    current_user_id = session["current_user_id"]

    if current_user_id do
      # Safely get user from database
      case Socialite.Repo.get(User, current_user_id) do
        %User{} = current_user ->
          # Get posts from database - include posts from followed users
          posts = Content.list_feed_posts(current_user_id)

          # Get upcoming events that the user is attending
          upcoming_events = Groups.get_upcoming_attending_events(current_user_id)
          |> Enum.take(3)  # Limit to 3 upcoming events

          # Get user's groups
          user_groups = Groups.get_user_groups(current_user_id)
          |> Enum.take(5)  # Limit to 5 groups

          # Get friends (users who follow each other)
          friends = get_user_friends(current_user_id)
          |> Enum.take(6)  # Limit to 6 friends

          # Calculate profile completion
          profile_completion = calculate_profile_completion(current_user)

          # Setup file upload
          socket =
            socket
            |> assign(:current_user, current_user)
            |> assign(:posts, posts)
            |> assign(:upcoming_events, upcoming_events)
            |> assign(:user_groups, user_groups)
            |> assign(:friends, friends)
            |> assign(:profile_completion, profile_completion)
            |> assign(:post_content, "")
            |> allow_upload(:image,
                accept: ~w(.jpg .jpeg .png .gif .webp),
                max_entries: 1,
                max_file_size: 5_000_000,
                auto_upload: true,
                progress: &handle_progress/3
              )

          {:ok, socket}

        nil ->
          # Invalid user ID in session, clear it and redirect to home
          {:ok, redirect(socket, to: "/")}
      end
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("validate_post", %{"post_content" => content}, socket) do
    {:noreply, assign(socket, :post_content, content)}
  end

  @impl true
  def handle_event("create_post", %{"post_content" => content}, socket) do
    current_user = socket.assigns.current_user

    # Get uploaded image URL if any
    image_url = case uploaded_entries(socket, :image) do
      {[_entry], []} ->
        # File uploaded successfully, get the URL
        [url] = consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
          # Here you would typically upload to a cloud service like S3
          # For now, we'll copy to a local directory
          dest = Path.join(["priv", "static", "uploads", "#{entry.uuid}.#{get_file_extension(entry.client_name)}"])
          File.mkdir_p!(Path.dirname(dest))
          File.cp!(path, dest)
          {:ok, "/uploads/#{entry.uuid}.#{get_file_extension(entry.client_name)}"}
        end)
        url
      _ ->
        nil
    end

    if String.trim(content) != "" do
      post_params = %{
        "content" => String.trim(content),
        "user_id" => current_user.id,
        "image_url" => image_url
      }

      case Content.create_post(post_params) do
        {:ok, _post} ->
          # Refresh posts and clear form
          posts = Content.list_feed_posts(current_user.id)

          socket =
            socket
            |> assign(:posts, posts)
            |> assign(:post_content, "")
            |> put_flash(:info, "Your post has been shared successfully!")

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create post. Please try again.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please write something before posting.")}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  defp handle_progress(:image, entry, socket) do
    if entry.done? do
      # File upload completed
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp get_file_extension(filename) do
    filename
    |> Path.extname()
    |> String.trim_leading(".")
    |> String.downcase()
  end

  defp error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  # Helper functions from PageController
  defp get_user_friends(user_id) do
    # Get users who follow each other (mutual follows)
    from(u in User,
      join: f1 in Socialite.Follow, on: f1.followed_id == u.id and f1.follower_id == ^user_id,
      join: f2 in Socialite.Follow, on: f2.follower_id == u.id and f2.followed_id == ^user_id,
      where: u.id != ^user_id,
      select: u
    )
    |> Socialite.Repo.all()
  end

  defp calculate_profile_completion(user) do
    fields = [
      {user.bio, "Bio"},
      {user.avatar, "Profile Picture"},
      {user.gender, "Gender"},
      {user.relationship_status, "Relationship Status"},
      {user.personality_type, "Personality Type"},
      {user.birthdate, "Birth Date"},
      {user.height, "Height"},
      {user.weight, "Weight"},
      {user.latitude && user.longitude, "Location"}
    ]

    completed_fields = Enum.filter(fields, fn {value, _name} ->
      value != nil and value != ""
    end)

    total_count = length(fields)
    completed_count = length(completed_fields)
    percentage = round(completed_count / total_count * 100)

    missing_items = fields
    |> Enum.reject(fn {value, _name} -> value != nil and value != "" end)
    |> Enum.map(fn {_value, name} -> name end)

    %{
      total_count: total_count,
      completed_count: completed_count,
      percentage: percentage,
      is_complete: percentage == 100,
      missing_items: missing_items
    }
  end
end
