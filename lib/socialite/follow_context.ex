defmodule Socialite.FollowContext do
  @moduledoc """
  The Follow context for managing user follows.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.{Follow, User}

  @doc """
  Follow a user.
  """
  def follow_user(follower_id, followed_id) do
    # Validate that users aren't trying to follow themselves
    if follower_id == followed_id do
      {:error, "Cannot follow yourself"}
    else
      # Check if already following
      case get_follow(follower_id, followed_id) do
        nil ->
          # Create the follow relationship
          %Follow{}
          |> Follow.changeset(%{follower_id: follower_id, followed_id: followed_id})
          |> Repo.insert()
          |> case do
            {:ok, follow} ->
              # Update the follower and followed counts
              update_follow_counts(follower_id, followed_id, :increment)
              {:ok, follow}
            {:error, changeset} ->
              {:error, changeset}
          end
        _existing ->
          {:error, "Already following this user"}
      end
    end
  end

  @doc """
  Unfollow a user.
  """
  def unfollow_user(follower_id, followed_id) do
    case get_follow(follower_id, followed_id) do
      nil ->
        {:error, "Not following this user"}
      follow ->
        Repo.delete(follow)
        |> case do
          {:ok, _} ->
            # Update the follower and followed counts
            update_follow_counts(follower_id, followed_id, :decrement)
            {:ok, :unfollowed}
          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Check if a user is following another user.
  """
  def following?(follower_id, followed_id) do
    get_follow(follower_id, followed_id) != nil
  end

  @doc """
  Get follow relationship between two users.
  """
  def get_follow(follower_id, followed_id) do
    Repo.get_by(Follow, follower_id: follower_id, followed_id: followed_id)
  end

  @doc """
  Get all users that a user is following.
  """
  def get_following(user_id) do
    from(f in Follow,
      where: f.follower_id == ^user_id,
      join: u in User, on: f.followed_id == u.id,
      select: u
    )
    |> Repo.all()
  end

  @doc """
  Get all followers of a user.
  """
  def get_followers(user_id) do
    from(f in Follow,
      where: f.followed_id == ^user_id,
      join: u in User, on: f.follower_id == u.id,
      select: u
    )
    |> Repo.all()
  end

  # Update follow counts for both users.
  defp update_follow_counts(follower_id, followed_id, operation) do
    case operation do
      :increment ->
        # Increment following count for follower
        from(u in User, where: u.id == ^follower_id)
        |> Repo.update_all(inc: [following_count: 1])

        # Increment followers count for followed
        from(u in User, where: u.id == ^followed_id)
        |> Repo.update_all(inc: [followers_count: 1])

      :decrement ->
        # Decrement following count for follower
        from(u in User, where: u.id == ^follower_id)
        |> Repo.update_all(inc: [following_count: -1])

        # Decrement followers count for followed
        from(u in User, where: u.id == ^followed_id)
        |> Repo.update_all(inc: [followers_count: -1])
    end
  end
end
