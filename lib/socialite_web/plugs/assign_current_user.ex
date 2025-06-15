defmodule SocialiteWeb.Plugs.AssignCurrentUser do
  import Plug.Conn
  import Ecto.Query
  alias Socialite.Messages
  alias Socialite.Notifications
  alias Socialite.Repo
  alias Socialite.Accounts.User

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user_id = get_session(conn, :current_user_id)

    current_user = if current_user_id do
      case Socialite.Repo.get(User, current_user_id) do
        %User{} = user -> user
        nil -> nil
      end
    else
      nil
    end

    # Get counts and friends list for notifications and messages if user is logged in
    {notifications_count, messages_count, friends_list} = if current_user do
      # Get recent friends (users that the current user is following)
      friends_query = from(f in "follows",
        join: u in User, on: f.followed_id == u.id,
        where: f.follower_id == ^current_user.id,
        select: %{
          id: u.id,
          first_name: u.first_name,
          last_name: u.last_name,
          avatar: u.avatar,
          city: u.city,
          state: u.state
        },
        order_by: [desc: f.inserted_at],
        limit: 10
      )

      friends = Repo.all(friends_query)

      {
        Notifications.unread_count(current_user.id),
        Messages.unread_count(current_user.id),
        friends
      }
    else
      {0, 0, []}
    end

    conn
    |> assign(:current_user, current_user)
    |> assign(:notifications_count, notifications_count)
    |> assign(:messages_count, messages_count)
    |> assign(:friends_list, friends_list)
  end
end
