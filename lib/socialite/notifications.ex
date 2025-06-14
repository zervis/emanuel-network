defmodule Socialite.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.Notification

  @doc """
  Returns the count of unread notifications for a user.
  """
  def unread_count(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at)
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns the list of notifications for a user.
  """
  def list_user_notifications(user_id, limit \\ 20) do
    from(n in Notification,
      where: n.user_id == ^user_id,
      order_by: [desc: n.inserted_at],
      limit: ^limit,
      preload: [:actor]
    )
    |> Repo.all()
  end

  @doc """
  Creates a notification.
  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a follow notification.
  """
  def create_follow_notification(follower_id, followed_id) do
    # Don't create notification if user follows themselves
    if follower_id != followed_id do
      follower = Socialite.Accounts.get_user!(follower_id)

      create_notification(%{
        type: "follow",
        message: "#{follower.first_name} #{follower.last_name} started following you",
        user_id: followed_id,
        actor_id: follower_id,
        data: %{}
      })
    end
  end

  @doc """
  Creates a kudos received notification.
  """
  def create_kudos_notification(giver_id, receiver_id, amount) do
    # Don't create notification if user gives kudos to themselves
    if giver_id != receiver_id do
      giver = Socialite.Accounts.get_user!(giver_id)

      create_notification(%{
        type: "kudos_received",
        message: "#{giver.first_name} #{giver.last_name} sent you #{amount} kudos!",
        user_id: receiver_id,
        actor_id: giver_id,
        data: %{amount: amount}
      })
    end
  end

  @doc """
  Marks a notification as read.
  """
  def mark_as_read(notification_id) do
    notification = Repo.get!(Notification, notification_id)
    notification
    |> Notification.mark_as_read()
    |> Repo.update()
  end

  @doc """
  Marks all notifications as read for a user.
  """
  def mark_all_as_read(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at)
    )
    |> Repo.update_all(set: [read_at: DateTime.utc_now()])
  end
end
