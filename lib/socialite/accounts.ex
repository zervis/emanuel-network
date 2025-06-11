defmodule Socialite.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.User

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    result = %User{}
    |> User.changeset(attrs)
    |> Repo.insert()

    case result do
      {:ok, user} ->
        # Automatically make new users follow Bogumił Gargula
        official_user = Repo.get_by(User, email: "bogumil@emanuel.network")
        if official_user && user.id != official_user.id do
          case Socialite.FollowContext.follow_user(user.id, official_user.id) do
            {:ok, _follow} ->
              IO.puts("New user #{user.first_name} #{user.last_name} is now following Bogumił Gargula")
            {:error, _} ->
              IO.puts("Failed to auto-follow Bogumił Gargula for #{user.first_name} #{user.last_name}")
          end
        end
        {:ok, user}
      error -> error
    end
  end

  @doc """
  Authenticates a user by email and password.
  """
  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && User.verify_password(user, password) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        # Perform a dummy check to prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :not_found}
    end
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Searches for users by first name, last name, or email, excluding the current user.
  """
  def search_users(query, current_user_id) do
    search_term = "%#{String.downcase(query)}%"

    from(u in User,
      where: u.id != ^current_user_id and
             (fragment("LOWER(?)", u.first_name) |> like(^search_term) or
              fragment("LOWER(?)", u.last_name) |> like(^search_term) or
              fragment("LOWER(?)", u.email) |> like(^search_term)),
      limit: 10,
      select: [:id, :first_name, :last_name, :email, :avatar]
    )
    |> Repo.all()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end
end
