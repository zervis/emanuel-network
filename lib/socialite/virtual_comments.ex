defmodule Socialite.VirtualComments do
  @moduledoc """
  GenServer to store virtual comments for the Emanuel.Network post (ID: -1) in memory.
  """
  use GenServer

  @virtual_post_id -1

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def add_comment(user_id, content) do
    GenServer.call(__MODULE__, {:add_comment, user_id, content})
  end

  def get_comments do
    GenServer.call(__MODULE__, :get_comments)
  end

  # Server callbacks

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_call({:add_comment, user_id, content}, _from, comments) do
    # Get the user information
    user = Socialite.Accounts.get_user!(user_id)

    # Create a virtual comment with a unique negative ID
    comment_id = -(length(comments) + 100)  # Start from -100 to avoid conflicts

    new_comment = %Socialite.Comment{
      id: comment_id,
      content: content,
      user_id: user_id,
      post_id: @virtual_post_id,
      user: user,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }

    # Add to the beginning of the list (newest first)
    updated_comments = [new_comment | comments]

    {:reply, {:ok, new_comment}, updated_comments}
  end

  @impl true
  def handle_call(:get_comments, _from, comments) do
    {:reply, comments, comments}
  end
end
