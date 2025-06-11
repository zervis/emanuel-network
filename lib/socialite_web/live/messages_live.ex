defmodule SocialiteWeb.MessagesLive do
  use SocialiteWeb, :live_view

  alias Socialite.Messages
  alias Socialite.Accounts

  @impl true
  def mount(_params, session, socket) do
    # Get current user from session
    current_user_id = session["current_user_id"]

    if current_user_id do
      # Safely get user from database
      case Socialite.Repo.get(Socialite.User, current_user_id) do
        %Socialite.User{} = current_user ->
          # Subscribe to user's message updates (only once per user)
          Phoenix.PubSub.subscribe(Socialite.PubSub, "user:#{current_user_id}")

          {:ok, assign(socket,
            current_user: current_user,
            conversations: Messages.list_conversations(current_user_id),
            active_conversation: nil,
            messages: [],
            new_message: "",
            conversation_users: Messages.get_conversation_users(current_user_id),
            unread_count: Messages.unread_count(current_user_id),
            subscribed_conversations: MapSet.new(),
            search_query: "",
            search_results: []
          )}

        nil ->
          {:ok, redirect(socket, to: "/")}
      end
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_params(%{"user_id" => user_id}, _uri, socket) do
    user_id = String.to_integer(user_id)
    active_conversation = Accounts.get_user!(user_id)

    # Get messages for this conversation
    messages = Messages.list_conversation(socket.assigns.current_user.id, user_id)
    |> Enum.reverse() # Show oldest first

    # Mark conversation as read
    Messages.mark_conversation_as_read(socket.assigns.current_user.id, user_id)

    # Subscribe to this specific conversation (avoid duplicates)
    conversation_topic = conversation_topic(socket.assigns.current_user.id, user_id)

    # Only subscribe if not already subscribed
    if not MapSet.member?(socket.assigns.subscribed_conversations, conversation_topic) do
      Phoenix.PubSub.subscribe(Socialite.PubSub, "conversation:#{conversation_topic}")
    end

    {:noreply, assign(socket,
      active_conversation: active_conversation,
      messages: messages,
      new_message: "",
      unread_count: Messages.unread_count(socket.assigns.current_user.id),
      subscribed_conversations: MapSet.put(socket.assigns.subscribed_conversations, conversation_topic)
    )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket,
      active_conversation: nil,
      messages: [],
      new_message: ""
    )}
  end

  @impl true
  def handle_event("search_users", params, socket) do
    # Handle both "query" and "value" parameter formats
    query = case params do
      %{"query" => q} -> String.trim(q)
      %{"value" => q} -> String.trim(q)
      _ -> ""
    end

    IO.inspect({params, query}, label: "Search event received")

    cond do
      String.length(query) >= 3 ->
        try do
          search_results = Accounts.search_users(query, socket.assigns.current_user.id)
          IO.inspect(search_results, label: "Search results")
          {:noreply, assign(socket, search_query: query, search_results: search_results)}
        rescue
          error ->
            IO.inspect(error, label: "Search error")
            {:noreply, assign(socket, search_query: query, search_results: [])
             |> put_flash(:error, "Error searching users. Please try again.")}
        end

      String.length(query) > 0 ->
        {:noreply, assign(socket, search_query: query, search_results: [])}

      true ->
        {:noreply, assign(socket, search_query: "", search_results: [])}
    end
  end

  @impl true
  def handle_event("start_conversation", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)

    # Clear search state and navigate to the conversation
    updated_socket = socket
      |> assign(search_query: "", search_results: [])
      |> push_patch(to: ~p"/messages/#{user_id}")

    {:noreply, updated_socket}
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, new_message: message)}
  end

  @impl true
  def handle_event("send_message", %{"message" => content}, socket) do
    content = String.trim(content)

    if content != "" and socket.assigns.active_conversation do
      case Messages.create_message(%{
        content: content,
        sender_id: socket.assigns.current_user.id,
        recipient_id: socket.assigns.active_conversation.id
      }) do
        {:ok, message} ->
          # Update local state immediately for better UX
          updated_messages = socket.assigns.messages ++ [message]
          updated_conversations = Messages.list_conversations(socket.assigns.current_user.id)

          {:noreply, assign(socket,
            messages: updated_messages,
            conversations: updated_conversations,
            new_message: ""
          )}
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to send message")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Only update if this message belongs to the current conversation
    if socket.assigns.active_conversation &&
       (message.sender_id == socket.assigns.active_conversation.id ||
        message.recipient_id == socket.assigns.active_conversation.id) do

      # Check if message is already in the list (avoid duplicates)
      existing_ids = Enum.map(socket.assigns.messages, & &1.id)

      if message.id not in existing_ids do
        updated_messages = socket.assigns.messages ++ [message]
        updated_conversations = Messages.list_conversations(socket.assigns.current_user.id)

        # Mark as read if this user is the recipient
        if message.recipient_id == socket.assigns.current_user.id do
          Messages.mark_as_read(message)
        end

        {:noreply, assign(socket,
          messages: updated_messages,
          conversations: updated_conversations,
          unread_count: Messages.unread_count(socket.assigns.current_user.id)
        )}
      else
        {:noreply, socket}
      end
    else
      # Update conversations list and unread count for messages from other conversations
      updated_conversations = Messages.list_conversations(socket.assigns.current_user.id)

      {:noreply, assign(socket,
        conversations: updated_conversations,
        unread_count: Messages.unread_count(socket.assigns.current_user.id)
      )}
    end
  end

  defp format_time(datetime) do
    Timex.from_now(datetime)
  end

  defp conversation_topic(user1_id, user2_id) do
    [user1_id, user2_id] |> Enum.sort() |> Enum.join(":")
  end
end
