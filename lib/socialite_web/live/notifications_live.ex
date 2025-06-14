defmodule SocialiteWeb.NotificationsLive do
  use SocialiteWeb, :live_view
  alias Socialite.Notifications

  def mount(_params, %{"current_user_id" => current_user_id}, socket) do
    notifications = Notifications.list_user_notifications(current_user_id, 10)

    {:ok,
     socket
     |> assign(:current_user_id, current_user_id)
     |> assign(:notifications, notifications)
     |> assign(:unread_count, Notifications.unread_count(current_user_id))}
  end

  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: ~p"/login")}
  end

  def handle_event("mark_all_read", _params, socket) do
    Notifications.mark_all_as_read(socket.assigns.current_user_id)

    {:noreply,
     socket
     |> assign(:unread_count, 0)
     |> put_flash(:info, "All notifications marked as read")}
  end

  def handle_event("mark_read", %{"id" => id}, socket) do
    Notifications.mark_as_read(String.to_integer(id))
    notifications = Notifications.list_user_notifications(socket.assigns.current_user_id, 10)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, Notifications.unread_count(socket.assigns.current_user_id))}
  end



    defp time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  defp notification_type_label(type) do
    case type do
      "follow" -> "Follow"
      "kudos_received" -> "Kudos"
      "post_like" -> "Like"
      "post_comment" -> "Comment"
      _ -> String.capitalize(type)
    end
  end

  defp notification_type_class(type) do
    case type do
      "follow" -> "bg-blue-100 text-blue-800"
      "kudos_received" -> "bg-yellow-100 text-yellow-800"
      "post_like" -> "bg-red-100 text-red-800"
      "post_comment" -> "bg-green-100 text-green-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
