defmodule Socialite.Content do
  @moduledoc """
  The Content context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.{Post, Comment, User, PostLike}

  @doc """
  Returns the list of posts with users and comments preloaded, ordered by newest first.
  """
  def list_posts do
    Repo.all(
      from p in Post,
        join: u in User, on: p.user_id == u.id,
        left_join: c in Comment, on: c.post_id == p.id,
        left_join: cu in User, on: c.user_id == cu.id,
        left_join: pl in PostLike, on: pl.post_id == p.id,
        left_join: plu in User, on: pl.user_id == plu.id,
        preload: [user: u, comments: {c, user: cu}, post_likes: {pl, user: plu}],
        order_by: [desc: p.inserted_at]
    )
  end

  @doc """
  Returns the list of posts for the feed - includes posts from users the current user follows
  and posts/events from groups the user has joined.
  """
  def list_feed_posts(user_id) do
    # Get regular posts from users that the current user follows, plus their own posts
    posts = Repo.all(
      from p in Post,
        join: u in User, on: p.user_id == u.id,
        left_join: f in Socialite.Follow, on: f.followed_id == p.user_id and f.follower_id == ^user_id,
        left_join: c in Comment, on: c.post_id == p.id,
        left_join: cu in User, on: c.user_id == cu.id,
        left_join: pl in PostLike, on: pl.post_id == p.id,
        left_join: plu in User, on: pl.user_id == plu.id,
        where: p.user_id == ^user_id or not is_nil(f.id),
        preload: [user: u, comments: {c, user: cu}, post_likes: {pl, user: plu}],
        order_by: [desc: p.inserted_at]
    )

    # Get group posts from groups the user has joined
    group_posts = Repo.all(
      from gp in Socialite.GroupPost,
        join: gm in Socialite.GroupMember, on: gm.group_id == gp.group_id and gm.user_id == ^user_id,
        join: u in User, on: gp.user_id == u.id,
        join: g in Socialite.Group, on: gp.group_id == g.id,
        left_join: c in Socialite.GroupPostComment, on: c.group_post_id == gp.id,
        left_join: cu in User, on: c.user_id == cu.id,
        preload: [user: u, group: g, group_post_comments: {c, user: cu}],
        order_by: [desc: gp.inserted_at]
    )

    # Get upcoming group events from groups the user has joined
    now = DateTime.utc_now()
    group_events = Repo.all(
      from ge in Socialite.GroupEvent,
        join: gm in Socialite.GroupMember, on: gm.group_id == ge.group_id and gm.user_id == ^user_id,
        join: u in User, on: ge.user_id == u.id,
        join: g in Socialite.Group, on: ge.group_id == g.id,
        where: ge.start_time > ^now,
        preload: [user: u, group: g],
        order_by: [asc: ge.start_time],
        limit: 10
    )

    # Add the official Bogumił Gargula post only if the user follows them or it's their own post
    official_user = Repo.get_by(User, email: "bogumil@emanuel.network")
    official_posts = if official_user do
      # Check if the user follows the official account or if it's the official user viewing their own feed
      follows_official = user_id == official_user.id ||
        Repo.exists?(from f in Socialite.Follow,
                     where: f.follower_id == ^user_id and f.followed_id == ^official_user.id)

      if follows_official do
        official_post = Repo.one(
          from p in Post,
            join: u in User, on: p.user_id == u.id,
            left_join: c in Comment, on: c.post_id == p.id,
            left_join: cu in User, on: c.user_id == cu.id,
            left_join: pl in PostLike, on: pl.post_id == p.id,
            left_join: plu in User, on: pl.user_id == plu.id,
            where: p.user_id == ^official_user.id,
            preload: [user: u, comments: {c, user: cu}, post_likes: {pl, user: plu}],
            order_by: [asc: p.inserted_at],
            limit: 1
        )

        if official_post && !Enum.any?(posts, fn p -> p.id == official_post.id end) do
          [official_post]
        else
          []
        end
      else
        []
      end
    else
      []
    end

    # Combine all content and sort by date
    all_content = posts ++ group_posts ++ group_events ++ official_posts

    # Sort by inserted_at or start_time for events
    # Convert NaiveDateTime to DateTime for comparison
    Enum.sort_by(all_content, fn
      %Socialite.GroupEvent{inserted_at: inserted_at} ->
        # Convert NaiveDateTime to DateTime assuming UTC
        DateTime.from_naive!(inserted_at, "Etc/UTC")
      %{inserted_at: inserted_at} ->
        # Convert NaiveDateTime to DateTime assuming UTC
        DateTime.from_naive!(inserted_at, "Etc/UTC")
    end, {:desc, DateTime})
  end

  @doc """
  Gets a single post.
  """
  def get_post!(id) do
    Repo.get!(Post, id)
    |> Repo.preload([:user, comments: :user, post_likes: :user])
  end

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
  Creates a comment.
  """
  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a comment.
  """
  def update_comment(%Comment{} = comment, attrs) do
    comment
    |> Comment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a comment.
  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking comment changes.
  """
  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end
end
