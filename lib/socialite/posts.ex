defmodule Socialite.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.Post

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
      preload: [:user, comments: :user],
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
      preload: [:user, comments: :user],
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
end
