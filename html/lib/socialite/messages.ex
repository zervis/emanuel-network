defmodule Socialite.Messages do
  @moduledoc """
  The Messages context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.Messages.Message

  @doc """
  Returns the list of messages.
  """
  def list_messages do
    Repo.all(Message)
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
  end

  @doc """
  Updates a message.
  """
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a message.
  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Gets conversation between two users.
  """
  def get_conversation(user1_id, user2_id) do
    from(m in Message,
      where: (m.sender_id == ^user1_id and m.recipient_id == ^user2_id) or
             (m.sender_id == ^user2_id and m.recipient_id == ^user1_id),
      order_by: [asc: m.inserted_at],
      preload: [:sender, :recipient])
    |> Repo.all()
  end

  @doc """
  Gets recent conversations for a user.
  """
  def get_recent_conversations(user_id) do
    # Get the most recent message for each conversation
    subquery =
      from(m in Message,
        where: m.sender_id == ^user_id or m.recipient_id == ^user_id,
        group_by: [
          fragment("CASE WHEN ? = ? THEN ? ELSE ? END", m.sender_id, ^user_id, m.recipient_id, m.sender_id)
        ],
        select: %{
          other_user_id: fragment("CASE WHEN ? = ? THEN ? ELSE ? END", m.sender_id, ^user_id, m.recipient_id, m.sender_id),
          max_inserted_at: max(m.inserted_at)
        })

    from(m in Message,
      join: s in subquery(subquery),
      on: ((m.sender_id == ^user_id and m.recipient_id == s.other_user_id) or
           (m.sender_id == s.other_user_id and m.recipient_id == ^user_id)) and
          m.inserted_at == s.max_inserted_at,
      order_by: [desc: m.inserted_at],
      preload: [:sender, :recipient])
    |> Repo.all()
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
  Gets unread message count for a user.
  """
  def get_unread_count(user_id) do
    from(m in Message,
      where: m.recipient_id == ^user_id and is_nil(m.read_at))
    |> Repo.aggregate(:count, :id)
  end
end
