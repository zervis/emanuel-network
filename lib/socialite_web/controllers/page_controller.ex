defmodule SocialiteWeb.PageController do
  use SocialiteWeb, :controller

  alias Socialite.Accounts
  alias Socialite.Content
  alias Socialite.Groups

  def home(conn, _params) do
    # Use the standard root layout so navigation and sidebar are shown
    render(conn, :home)
  end

  def feed(conn, _params) do
    # Get current user from session
    current_user_id = get_session(conn, :current_user_id)
    IO.inspect(current_user_id, label: "FEED - Current User ID from Session")

    if current_user_id do
      # Safely get user from database
      case Socialite.Repo.get(Socialite.User, current_user_id) do
        %Socialite.User{} = current_user ->
          # Get posts from database - include posts from followed users
          posts = Content.list_feed_posts(current_user_id)

          # Get upcoming events that the user is attending
          upcoming_events = Socialite.Groups.get_upcoming_attending_events(current_user_id)
          |> Enum.take(3)  # Limit to 3 upcoming events

          # Get user's groups
          user_groups = Socialite.Groups.get_user_groups(current_user_id)
          |> Enum.take(5)  # Limit to 5 groups

          # Get friends (users who follow each other)
          friends = get_user_friends(current_user_id)
          |> Enum.take(6)  # Limit to 6 friends

          # Calculate profile completion
          profile_completion = calculate_profile_completion(current_user)

          # Render the feed page for logged-in users
          render(conn, :feed,
            posts: posts,
            current_user: current_user,
            upcoming_events: upcoming_events,
            user_groups: user_groups,
            friends: friends,
            profile_completion: profile_completion
          )

        nil ->
          # Invalid user ID in session, clear it and redirect to home
          conn
          |> clear_session()
          |> put_flash(:error, "Your session has expired. Please log in again.")
          |> redirect(to: ~p"/")
      end
    else
      conn
      |> put_flash(:error, "Please log in to access the feed.")
      |> redirect(to: ~p"/")
    end
  end

  # Helper function to calculate profile completion percentage
  defp calculate_profile_completion(user) do
    # Check required fields for profile completion
    checks = [
      # Location provided (latitude and longitude)
      {user.latitude != nil and user.longitude != nil, "Add your location"},
      # Bio provided
      {user.bio != nil and String.trim(user.bio || "") != "", "Add a bio"},
      # Pictures uploaded
      {Accounts.count_user_pictures(user.id) > 0, "Upload pictures"},
      # Birth date set
      {user.birthdate != nil, "Set your birth date"},
      # Gender set
      {user.gender != nil and user.gender != "", "Set your gender"},
      # Personality type set
      {user.personality_type != nil and user.personality_type != "", "Set your personality type"}
    ]

    completed_count = Enum.count(checks, fn {completed, _} -> completed end)
    total_count = length(checks)
    percentage = round(completed_count / total_count * 100)

    missing_items = checks
    |> Enum.filter(fn {completed, _} -> not completed end)
    |> Enum.map(fn {_, description} -> description end)

    %{
      percentage: percentage,
      completed_count: completed_count,
      total_count: total_count,
      missing_items: missing_items,
      is_complete: percentage == 100
    }
  end

  # Helper function to get user's friends (mutual follows)
  defp get_user_friends(user_id) do
    import Ecto.Query

    # Get users who the current user follows AND who follow the current user back
    Socialite.Repo.all(
      from u in Socialite.User,
        join: f1 in Socialite.Follow, on: f1.followed_id == u.id and f1.follower_id == ^user_id,
        join: f2 in Socialite.Follow, on: f2.follower_id == u.id and f2.followed_id == ^user_id,
        where: u.id != ^user_id,
        select: u,
        order_by: [desc: u.inserted_at]
    )
  end

  def profile(conn, _params) do
    # Render the profile page
    render(conn, :profile)
  end

  def messages(conn, _params) do
    # Render the messages page
    render(conn, :messages)
  end

  def friends(conn, _params) do
    # Render the friends page
    render(conn, :friends)
  end

  def groups(conn, _params) do
    # Render the groups page
    render(conn, :groups)
  end

  def events(conn, _params) do
    # Render the events page
    render(conn, :events)
  end

  # Handle login with email and password
  def login(conn, %{"email" => email, "password" => password}) do
    IO.inspect(email, label: "LOGIN ATTEMPT - Email")
    IO.inspect(password, label: "LOGIN ATTEMPT - Password")

    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        IO.inspect(user.id, label: "LOGIN SUCCESS - User ID")

        conn
        |> put_session(:current_user_id, user.id)
        |> put_flash(:info, "Login successful! Welcome back to Emanuel Network, #{user.first_name}!")
        |> redirect(to: ~p"/feed")

      {:error, :invalid_password} ->
        IO.inspect("INVALID PASSWORD", label: "LOGIN ERROR")
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/")

      {:error, :not_found} ->
        IO.inspect("USER NOT FOUND", label: "LOGIN ERROR")
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/")
    end
  end

  # Handle cases where required login parameters are missing
  def login(conn, _params) do
    IO.inspect("MISSING EMAIL OR PASSWORD", label: "LOGIN ERROR")
    conn
    |> put_flash(:error, "Please provide both email and password.")
    |> redirect(to: ~p"/")
  end

  # Handle registration with all required fields
  def register(conn, %{"first_name" => first_name, "last_name" => last_name, "email" => email, "password" => password, "password_confirmation" => password_confirmation}) do
    IO.inspect(%{
      first_name: first_name,
      last_name: last_name,
      email: email,
      password: String.length(password),
      password_confirmation: String.length(password_confirmation)
    }, label: "REGISTER ATTEMPT - User Data")

    user_params = %{
      "first_name" => first_name,
      "last_name" => last_name,
      "email" => email,
      "password" => password,
      "password_confirmation" => password_confirmation
    }

    case Accounts.create_user(user_params) do
      {:ok, user} ->
        IO.inspect(user.id, label: "REGISTER SUCCESS - User ID")

        conn
        |> put_session(:current_user_id, user.id)
        |> put_flash(:info, "Registration successful! Welcome to Emanuel Network, #{user.first_name}!")
        |> redirect(to: ~p"/feed")

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "REGISTER ERROR - Changeset")

        # Extract error messages from changeset
        error_message =
          changeset.errors
          |> Enum.map(fn {field, {message, _}} -> "#{field} #{message}" end)
          |> Enum.join(", ")

        conn
        |> put_flash(:error, "Registration failed: #{error_message}")
        |> redirect(to: ~p"/")
    end
  end

  # Handle cases where required registration parameters are missing
  def register(conn, params) do
    IO.inspect(params, label: "REGISTER ERROR - Missing/Invalid Params")

    conn
    |> put_flash(:error, "Please fill in all required fields.")
    |> redirect(to: ~p"/")
  end

  # Handle creating a new post
  def create_post(conn, %{"content" => content}) when content != "" do
    current_user_id = get_session(conn, :current_user_id)

    if current_user_id do
      post_params = %{
        "content" => String.trim(content),
        "user_id" => current_user_id
      }

      case Content.create_post(post_params) do
        {:ok, _post} ->
          conn
          |> put_flash(:info, "Your post has been shared successfully!")
          |> redirect(to: ~p"/feed")

        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Failed to create post. Please try again.")
          |> redirect(to: ~p"/feed")
      end
    else
      conn
      |> put_flash(:error, "Please log in to create posts.")
      |> redirect(to: ~p"/")
    end
  end

  def create_post(conn, _params) do
    conn
    |> put_flash(:error, "Please write something before posting.")
    |> redirect(to: ~p"/feed")
  end

  # Handle creating a new comment
  def create_comment(conn, %{"post_id" => post_id, "comment" => comment}) when comment != "" do
    current_user_id = get_session(conn, :current_user_id)

    if current_user_id do
      comment_params = %{
        "content" => String.trim(comment),
        "user_id" => current_user_id,
        "post_id" => post_id
      }

      case Content.create_comment(comment_params) do
        {:ok, _comment} ->
          conn
          |> put_flash(:info, "Your comment has been added!")
          |> redirect(to: ~p"/feed")

        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Failed to add comment. Please try again.")
          |> redirect(to: ~p"/feed")
      end
    else
      conn
      |> put_flash(:error, "Please log in to comment.")
      |> redirect(to: ~p"/")
    end
  end

  def create_comment(conn, _params) do
    conn
    |> put_flash(:error, "Please write a comment before posting.")
    |> redirect(to: ~p"/feed")
  end

  # Clear session route for debugging
  def clear_session(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Session cleared. Please login again.")
    |> redirect(to: ~p"/")
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "You have been logged out successfully.")
    |> redirect(to: ~p"/")
  end

  def terms(conn, _params) do
    # Render the terms of use page for unauthenticated users
    render(conn, :terms)
  end

  def teaching(conn, _params) do
    # Render the teaching page for unauthenticated users
    render(conn, :teaching)
  end

  def search(conn, %{"q" => query}) when query != "" do
    current_user_id = get_session(conn, :current_user_id)

    if current_user_id do
      # Get current user for layout and distance calculations
      current_user = Socialite.Repo.get!(Socialite.User, current_user_id)

      # Search both users and groups with distance calculations
      users = Accounts.search_users(query, current_user_id)
      users_with_distance = Accounts.add_distance_to_users(users, current_user.latitude, current_user.longitude)

      # Add compatibility information to users
      users_with_compatibility = Enum.map(users_with_distance, fn user ->
        compatibility = Socialite.Tags.calculate_compatibility(current_user_id, user.id)
        Map.put(user, :compatibility, compatibility)
      end)

      groups = Groups.search_groups(query)
      groups_with_distance = Groups.add_distance_to_groups(groups, current_user.latitude, current_user.longitude)

      render(conn, :search,
        query: query,
        users: users_with_compatibility,
        groups: groups_with_distance,
        current_user: current_user
      )
    else
      conn
      |> put_flash(:error, "Please log in to search.")
      |> redirect(to: ~p"/")
    end
  end

  def search(conn, _params) do
    current_user_id = get_session(conn, :current_user_id)

    if current_user_id do
      current_user = Socialite.Repo.get!(Socialite.User, current_user_id)

      render(conn, :search,
        query: "",
        users: [],
        groups: [],
        current_user: current_user
      )
    else
      conn
      |> put_flash(:error, "Please log in to search.")
      |> redirect(to: ~p"/")
    end
  end
end
