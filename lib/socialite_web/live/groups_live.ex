defmodule SocialiteWeb.GroupsLive do
  use SocialiteWeb, :live_view

  alias Socialite.{Groups, Accounts}

  @impl true
  def mount(_params, session, socket) do
    current_user_id = session["current_user_id"]

    # Add safety check for current_user_id
    if current_user_id do
      # Use Repo.get instead of get_user! to avoid exceptions
      case Socialite.Repo.get(Socialite.User, current_user_id) do
        %Socialite.User{} = current_user ->
          {:ok,
           socket
           |> assign(:current_user, current_user)
           |> assign(:groups, [])
           |> assign(:user_groups, Groups.get_user_groups(current_user_id))
           |> assign(:nearby_groups, [])
           |> assign(:search_location, nil)
           |> assign(:loading, false)
}

        nil ->
          {:ok, redirect(socket, to: "/")}
      end
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search_nearby", %{"lat" => lat, "lng" => lng}, socket) do
    {lat_float, _} = Float.parse(lat)
    {lng_float, _} = Float.parse(lng)

    nearby_groups = Groups.find_nearby_groups(lat_float, lng_float, 10_000)

    {:noreply,
     socket
     |> assign(:nearby_groups, nearby_groups)
     |> assign(:search_location, %{lat: lat_float, lng: lng_float})}
  end

  @impl true
  def handle_event("join_group", %{"group_id" => group_id}, socket) do
    group_id = String.to_integer(group_id)

    case Groups.join_group(socket.assigns.current_user.id, group_id) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully joined the group!")
         |> assign(:user_groups, Groups.get_user_groups(socket.assigns.current_user.id))}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to join group")}
    end
  end

  @impl true
  def handle_event("leave_group", %{"group_id" => group_id}, socket) do
    group_id = String.to_integer(group_id)

    case Groups.leave_group(socket.assigns.current_user.id, group_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Left the group successfully!")
         |> assign(:user_groups, Groups.get_user_groups(socket.assigns.current_user.id))}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to leave group")}
    end
  end

  @impl true
  def handle_event("get_location", _params, socket) do
    {:noreply, push_event(socket, "get_user_location", %{})}
  end

  @impl true
  def handle_event("location_received", %{"lat" => lat, "lng" => lng}, socket) do
    handle_event("search_nearby", %{"lat" => to_string(lat), "lng" => to_string(lng)}, socket)
  end



  defp is_member?(user_groups, group_id) do
    Enum.any?(user_groups, fn g -> g.id == group_id end)
  end
end
