defmodule SocialiteWeb.CreateEventLive do
  use SocialiteWeb, :live_view
  alias Socialite.Groups

    @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    if current_user do
      {:ok,
       socket
       |> assign(:current_user, current_user)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to create events")
       |> push_redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(%{"group_id" => group_id}, _url, socket) do
    current_user = socket.assigns.current_user
    group = Groups.get_group!(group_id)

    # Check if user is a member of the group
    unless Groups.member?(current_user.id, group.id) do
      {:noreply,
       socket
       |> put_flash(:error, "You must be a member of this group to create events")
       |> push_redirect(to: ~p"/groups/#{group.id}")}
    else
      changeset = Groups.change_group_event(%Socialite.GroupEvent{}, %{
        "user_id" => current_user.id,
        "group_id" => group.id
      })

      {:noreply,
       socket
       |> assign(:group, group)
       |> assign(:changeset, changeset)
       |> assign(:page_title, "Create Event - #{group.name}")}
    end
  end

  @impl true
  def handle_event("validate", %{"group_event" => event_params}, socket) do
    changeset =
      %Socialite.GroupEvent{}
      |> Groups.change_group_event(event_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"group_event" => event_params}, socket) do
    event_params = Map.merge(event_params, %{
      "user_id" => socket.assigns.current_user.id,
      "group_id" => socket.assigns.group.id
    })

    case Groups.create_group_event(event_params) do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event created successfully!")
         |> push_redirect(to: ~p"/groups/#{socket.assigns.group.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_redirect(socket, to: ~p"/groups/#{socket.assigns.group.id}")}
  end

  defp get_current_user(session) do
    case session["current_user_id"] do
      nil -> nil
      user_id -> Socialite.Repo.get!(Socialite.User, user_id)
    end
  end


end
