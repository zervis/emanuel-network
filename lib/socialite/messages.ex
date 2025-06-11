defmodule Socialite.Messages do
  @moduledoc """
  The Messages context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.Message
  alias Socialite.User

  @doc """
  Returns the list of messages between two users.
  """
  def list_conversation(user1_id, user2_id) do
    from(m in Message,
      where: (m.sender_id == ^user1_id and m.recipient_id == ^user2_id) or
             (m.sender_id == ^user2_id and m.recipient_id == ^user1_id),
      order_by: [desc: m.inserted_at],
      preload: [:sender, :recipient]
    )
    |> Repo.all()
  end

  @doc """
  Returns recent conversations for a user.
  """
  def list_conversations(user_id) do
    # Get all messages involving the user
    messages = from(m in Message,
      where: m.sender_id == ^user_id or m.recipient_id == ^user_id,
      order_by: [desc: m.inserted_at],
      preload: [:sender, :recipient]
    )
    |> Repo.all()

    # Group by conversation partner and get the latest message for each
    messages
    |> Enum.group_by(fn message ->
      if message.sender_id == user_id do
        message.recipient_id
      else
        message.sender_id
      end
    end)
    |> Enum.map(fn {_partner_id, conversation_messages} ->
      # Get the most recent message in this conversation
      Enum.max_by(conversation_messages, &(&1.inserted_at))
    end)
    |> Enum.sort_by(&(&1.inserted_at), :desc)
  end

  @doc """
  Gets a single message.
  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Creates a message.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        # Preload associations for the message
        message = Repo.preload(message, [:sender, :recipient])

        # Broadcast the new message to the conversation topic
        conversation_topic = conversation_topic(message.sender_id, message.recipient_id)
        Phoenix.PubSub.broadcast(
          Socialite.PubSub,
          "conversation:#{conversation_topic}",
          {:new_message, message}
        )

        {:ok, message}
      error -> error
    end
  end

  @doc """
  Marks a message as read.
  """
  def mark_as_read(%Message{} = message) do
    message
    |> Message.mark_as_read()
    |> Repo.update()
  end

  @doc """
  Marks all messages in a conversation as read for the given user.
  """
  def mark_conversation_as_read(user_id, other_user_id) do
    from(m in Message,
      where: m.sender_id == ^other_user_id and m.recipient_id == ^user_id and is_nil(m.read_at)
    )
    |> Repo.update_all(set: [read_at: DateTime.utc_now()])
  end

  @doc """
  Returns the count of unread messages for a user.
  """
  def unread_count(user_id) do
    from(m in Message,
      where: m.recipient_id == ^user_id and is_nil(m.read_at)
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets all users that a user has conversations with.
  """
  def get_conversation_users(user_id) do
    subquery = from(m in Message,
      where: m.sender_id == ^user_id or m.recipient_id == ^user_id,
      select: fragment("CASE WHEN ? = ? THEN ? ELSE ? END",
        m.sender_id, ^user_id, m.recipient_id, m.sender_id),
      distinct: true
    )

    from(u in User,
      where: u.id in subquery(subquery),
      select: [:id, :first_name, :last_name, :avatar]
    )
    |> Repo.all()
  end

  defp conversation_topic(user1_id, user2_id) do
    [user1_id, user2_id] |> Enum.sort() |> Enum.join(":")
  end
end
