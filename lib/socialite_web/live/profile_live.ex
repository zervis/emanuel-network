defmodule SocialiteWeb.ProfileLive do
  use SocialiteWeb, :live_view

  alias Socialite.Accounts
  alias Socialite.Posts
  alias Socialite.KudosContext
  alias Socialite.FollowContext

  @impl true
  def mount(%{"user_id" => user_id}, session, socket) do
    current_user_id = session["current_user_id"]

    # Safely get both users from database
    with %Socialite.User{} = current_user <- Socialite.Repo.get(Socialite.User, current_user_id),
         %Socialite.User{} = profile_user <- Socialite.Repo.get(Socialite.User, user_id) do

      # Get user's posts
      posts = Posts.list_user_posts(user_id)

      # Reset daily credits if needed and get updated current user
      updated_current_user = KudosContext.reset_daily_credits_if_needed(current_user)

      # Check if current user is following the profile user
      is_following = FollowContext.following?(current_user.id, profile_user.id)

      {:ok, assign(socket,
        current_user: updated_current_user,
        profile_user: profile_user,
        posts: posts,
        is_own_profile: current_user.id == profile_user.id,
        is_following: is_following,
        kudos_amount: 1
      )}
    else
      nil ->
        {:ok, redirect(socket, to: "/")}
    end
  end

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
