defmodule SocialiteWeb.CreateGroupLive do
  use SocialiteWeb, :live_view

  alias Socialite.Groups
  alias Socialite.Group

    def mount(_params, session, socket) do
    current_user_id = session["current_user_id"]

    if current_user_id do
      current_user = Socialite.Accounts.get_user!(current_user_id)
      changeset = Groups.change_group(%Group{}, %{"creator_id" => current_user.id})

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:group_changeset, changeset)
        |> assign(:form, to_form(changeset))

      {:ok, socket}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

    def handle_event("validate_group", %{"group" => group_params}, socket) do
    # Add the creator_id to the params during validation
    group_params_with_creator = Map.put(group_params, "creator_id", socket.assigns.current_user.id)

    changeset =
      %Group{}
      |> Groups.change_group(group_params_with_creator)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:group_changeset, changeset)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("create_group", %{"group" => group_params}, socket) do
    current_user = socket.assigns.current_user

    # Add creator_id to the group params
    group_attrs = Map.put(group_params, "creator_id", current_user.id)

    case Groups.create_group(group_attrs) do
      {:ok, group} ->
        {:noreply,
         socket
         |> put_flash(:info, "Group created successfully!")
         |> redirect(to: ~p"/groups/#{group.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:group_changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end
end
