defmodule Socialite.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.{Post, PostLike}

  @doc """
  Returns the list of posts.
  """
  def list_posts do
    Repo.all(Post)
  end

  @doc """
  Returns the list of posts for the feed - includes posts from users the current user follows.
  """
  def list_feed_posts(user_id) do
    # Get posts from users that the current user follows, plus their own posts
    from(p in Post,
      join: u in assoc(p, :user),
      left_join: f in Socialite.Follow, on: f.followed_id == p.user_id and f.follower_id == ^user_id,
      where: p.user_id == ^user_id or not is_nil(f.id),
      preload: [:user, comments: :user, post_likes: :user],
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of posts for a specific user.
  """
  def list_user_posts(user_id) do
    from(p in Post,
      where: p.user_id == ^user_id,
      preload: [:user, comments: :user, post_likes: :user],
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single post.
  """
  def get_post!(id), do: Repo.get!(Post, id)

  @doc """
  Creates a post.
  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post.
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a post.
  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Likes a post by a user.
  """
  def like_post(user_id, post_id) do
    case Repo.get_by(PostLike, user_id: user_id, post_id: post_id) do
      nil ->
        # Create the like
        result = %PostLike{}
        |> PostLike.changeset(%{user_id: user_id, post_id: post_id})
        |> Repo.insert()

        case result do
          {:ok, _like} ->
            # Update the likes count
            update_likes_count(post_id)
            {:ok, :liked}
          error ->
            error
        end
      _existing_like ->
        {:error, :already_liked}
    end
  end

  @doc """
  Unlikes a post by a user.
  """
  def unlike_post(user_id, post_id) do
    case Repo.get_by(PostLike, user_id: user_id, post_id: post_id) do
      nil ->
        {:error, :not_liked}
      like ->
        result = Repo.delete(like)
        case result do
          {:ok, _like} ->
            # Update the likes count
            update_likes_count(post_id)
            {:ok, :unliked}
          error ->
            error
        end
    end
  end

  @doc """
  Toggles like status for a post by a user.
  """
  def toggle_like(user_id, post_id) do
    case Repo.get_by(PostLike, user_id: user_id, post_id: post_id) do
      nil ->
        like_post(user_id, post_id)
      _existing_like ->
        unlike_post(user_id, post_id)
    end
  end

  @doc """
  Checks if a user has liked a post.
  """
  def user_liked_post?(user_id, post_id) do
    Repo.exists?(from pl in PostLike, where: pl.user_id == ^user_id and pl.post_id == ^post_id)
  end

  @doc """
  Updates the likes count for a post.
  """
  defp update_likes_count(post_id) do
    count = Repo.aggregate(
      from(pl in PostLike, where: pl.post_id == ^post_id),
      :count
    )

    Repo.update_all(
      from(p in Post, where: p.id == ^post_id),
      set: [likes_count: count]
    )
  end
end
