defmodule SocialiteWeb.KudosLive do
  use SocialiteWeb, :live_view

  alias Socialite.{KudosContext, FollowContext}
  alias Socialite.User

  @impl true
  def mount(%{"user_id" => user_id}, session, socket) do
    current_user_id = session["current_user_id"]

    # Require authentication
    if is_nil(current_user_id) do
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to give kudos")
       |> push_navigate(to: ~p"/")}
    else
      mount_kudos_page(user_id, current_user_id, socket)
    end
  end

  defp mount_kudos_page(user_id, current_user_id, socket) do
    # Convert ids to integers if they're strings
    recipient_user_id = case user_id do
      id when is_binary(id) -> String.to_integer(id)
      id when is_integer(id) -> id
    end

    current_user_id = case current_user_id do
      id when is_binary(id) -> String.to_integer(id)
      id when is_integer(id) -> id
    end

    # Can't give kudos to yourself
    if current_user_id == recipient_user_id do
      {:ok,
       socket
       |> put_flash(:error, "You cannot give kudos to yourself")
       |> push_navigate(to: ~p"/profile/#{recipient_user_id}")}
    else
      # Get current user and recipient user
      case {Socialite.Repo.get(User, current_user_id), Socialite.Repo.get(User, recipient_user_id)} do
        {%User{} = current_user, %User{} = recipient_user} ->
          # Check if users are following each other (optional requirement)
          is_following = FollowContext.following?(current_user_id, recipient_user_id)

          {:ok,
           socket
           |> assign(:current_user, current_user)
           |> assign(:recipient_user, recipient_user)
           |> assign(:is_following, is_following)
           |> assign(:kudos_amount, 1)
           |> assign(:page_title, "Give Kudos to #{recipient_user.first_name}")}

        {nil, _} ->
          {:ok,
           socket
           |> put_flash(:error, "User not found")
           |> push_navigate(to: ~p"/")}

        {_, nil} ->
          {:ok,
           socket
           |> put_flash(:error, "Recipient not found")
           |> push_navigate(to: ~p"/")}
      end
    end
  end

  @impl true
  def handle_event("update_kudos_amount", %{"amount" => amount}, socket) do
    amount = String.to_integer(amount)
    max_credits = socket.assigns.current_user.daily_kudos_credits

    # Ensure amount is within valid range
    amount = cond do
      amount < 1 -> 1
      amount > max_credits -> max_credits
      true -> amount
    end

    {:noreply, assign(socket, :kudos_amount, amount)}
  end

  @impl true
  def handle_event("give_kudos", _params, socket) do
    current_user = socket.assigns.current_user
    recipient_user = socket.assigns.recipient_user
    kudos_amount = socket.assigns.kudos_amount

    # Check if user has enough credits
    if current_user.daily_kudos_credits >= kudos_amount do
      case KudosContext.give_kudos(current_user.id, recipient_user.id, kudos_amount) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Successfully gave #{kudos_amount} kudos to #{recipient_user.first_name}!")
           |> push_navigate(to: ~p"/profile/#{recipient_user.id}")}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to give kudos: #{reason}")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have enough daily kudos credits")}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    recipient_user = socket.assigns.recipient_user
    {:noreply, push_navigate(socket, to: ~p"/profile/#{recipient_user.id}")}
  end
end
