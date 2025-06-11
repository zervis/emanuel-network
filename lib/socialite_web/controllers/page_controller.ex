defmodule SocialiteWeb.PageController do
  use SocialiteWeb, :controller

  alias Socialite.Accounts
  alias Socialite.Content

  def home(conn, _params) do
    # Use the default app layout to ensure proper CSRF protection
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

          # Render the feed page for logged-in users
          render(conn, :feed, posts: posts, current_user: current_user)

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
end
