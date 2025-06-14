defmodule SocialiteWeb.ProfileLive do
  use SocialiteWeb, :live_view

  alias Socialite.Accounts
  alias Socialite.Posts
  alias Socialite.KudosContext
  alias Socialite.FollowContext
  alias Socialite.Groups
  alias Socialite.User
  alias Socialite.Tags

  @impl true
  def mount(%{"id" => id} = params, session, socket) do
    mount_profile(id, session, socket)
  end

  def mount(%{"user_id" => user_id} = params, session, socket) do
    mount_profile(user_id, session, socket)
  end

  defp mount_profile(id, session, socket) do
    current_user_id = session["current_user_id"]

    # Safely get both users from database
    with %User{} = current_user <- Socialite.Repo.get(User, current_user_id),
         %User{} = profile_user <- Socialite.Repo.get(User, id) do

      # Get user's pictures
      user_pictures = Accounts.list_user_pictures(profile_user.id)

      # Get user's joined groups
      joined_groups = Groups.get_user_groups(profile_user.id)

      # Get user's upcoming events
      upcoming_events = Groups.get_user_upcoming_events(profile_user.id)

      # Calculate distance between users if both have location data
      distance = calculate_distance(current_user, profile_user)

      # Calculate compatibility between users (only if viewing someone else's profile)
      compatibility = if current_user.id != profile_user.id do
        Tags.calculate_compatibility(current_user.id, profile_user.id)
      else
        nil
      end

      # Get posts by this user
      posts = Posts.list_user_posts(profile_user.id)

      # Get nearby users (only for own profile)
      nearby_users = if current_user.id == profile_user.id do
        Accounts.find_nearby_users_for_user(current_user, 50) # 50km radius
      else
        []
      end

      # Check if following
      is_following = if current_user.id != profile_user.id do
        FollowContext.following?(current_user.id, profile_user.id)
      else
        false
      end

      # Get follow counts from user record
      followers_count = profile_user.followers_count || 0
      following_count = profile_user.following_count || 0

      # Get user's tags
      user_tags = Tags.get_user_tags_by_category(profile_user.id)

      # Calculate age for the profile user
      profile_user_with_age = %{profile_user | age: User.age(profile_user)}

             {:ok,
        socket
        |> assign(:current_user, current_user)
        |> assign(:profile_user, profile_user_with_age)
        |> assign(:user_pictures, user_pictures)
        |> assign(:user_groups, joined_groups)
        |> assign(:upcoming_events, upcoming_events)
        |> assign(:distance, distance)
        |> assign(:compatibility, compatibility)
        |> assign(:posts, posts)
        |> assign(:nearby_users, nearby_users)
        |> assign(:is_own_profile, current_user.id == profile_user.id)
        |> assign(:is_following, is_following)
        |> assign(:followers_count, followers_count)
        |> assign(:following_count, following_count)
        |> assign(:user_tags, user_tags)
        |> assign(:kudos_amount, 1)}
    else
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> redirect(to: ~p"/feed")}
    end
  end

  # Calculate distance between two users using Haversine formula
  defp calculate_distance(%User{latitude: lat1, longitude: lon1}, %User{latitude: lat2, longitude: lon2})
    when not is_nil(lat1) and not is_nil(lon1) and not is_nil(lat2) and not is_nil(lon2) do

    # Convert degrees to radians
    lat1_rad = lat1 * :math.pi() / 180
    lon1_rad = lon1 * :math.pi() / 180
    lat2_rad = lat2 * :math.pi() / 180
    lon2_rad = lon2 * :math.pi() / 180

    # Haversine formula
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad

    a = :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
        :math.sin(dlon / 2) * :math.sin(dlon / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    # Earth's radius in kilometers
    earth_radius = 6371

    # Calculate distance
    distance = earth_radius * c

    # Round to 1 decimal place
    Float.round(distance, 1)
  end

  defp calculate_distance(_, _), do: nil

  @impl true
  def handle_event("give_kudos", %{"amount" => amount_str}, socket) do
    giver_id = socket.assigns.current_user.id
    receiver_id = socket.assigns.profile_user.id
    amount = String.to_integer(amount_str)

    case KudosContext.give_kudos(giver_id, receiver_id, amount) do
      {:ok, _kudos} ->
        # Update both users in the socket
        updated_profile_user = Accounts.get_user!(receiver_id)
        updated_current_user = Accounts.get_user!(giver_id)

        {:noreply, socket
         |> assign(profile_user: updated_profile_user, current_user: updated_current_user)
         |> put_flash(:info, "#{amount} kudos sent successfully! You have #{updated_current_user.daily_kudos_credits} credits remaining.")
        }
      {:error, changeset} ->
        error_message = case changeset do
          %Ecto.Changeset{errors: errors} ->
            errors
            |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
            |> Enum.join(", ")
          error_string when is_binary(error_string) ->
            error_string
          _ ->
            "Unable to give kudos"
        end

        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  @impl true
  def handle_event("update_kudos_amount", %{"amount" => amount_str}, socket) do
    amount = String.to_integer(amount_str)
    {:noreply, assign(socket, kudos_amount: amount)}
  end

  @impl true
  def handle_event("start_conversation", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/messages/#{socket.assigns.profile_user.id}")}
  end

  @impl true
  def handle_event("follow_user", _params, socket) do
    follower_id = socket.assigns.current_user.id
    followed_id = socket.assigns.profile_user.id

    case FollowContext.follow_user(follower_id, followed_id) do
      {:ok, _follow} ->
        updated_profile_user = Accounts.get_user!(followed_id)
        {:noreply, socket
         |> assign(is_following: true, profile_user: updated_profile_user)
         |> put_flash(:info, "You are now following #{updated_profile_user.first_name}!")
        }
      {:error, error} ->
        error_message = if is_binary(error), do: error, else: "Unable to follow user"
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  @impl true
  def handle_event("unfollow_user", _params, socket) do
    follower_id = socket.assigns.current_user.id
    followed_id = socket.assigns.profile_user.id

    case FollowContext.unfollow_user(follower_id, followed_id) do
      {:ok, :unfollowed} ->
        updated_profile_user = Accounts.get_user!(followed_id)
        {:noreply, socket
         |> assign(is_following: false, profile_user: updated_profile_user)
         |> put_flash(:info, "You unfollowed #{updated_profile_user.first_name}")
        }
      {:error, error} ->
        error_message = if is_binary(error), do: error, else: "Unable to unfollow user"
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end
end
