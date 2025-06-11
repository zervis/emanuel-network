defmodule Socialite.KudosContext do
  @moduledoc """
  The Kudos context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.Kudos
  alias Socialite.User

  @doc """
  Give kudos from one user to another using daily credits.
  """
  def give_kudos(giver_id, receiver_id, amount \\ 1)
  def give_kudos(giver_id, receiver_id, amount) when giver_id != receiver_id do
    giver = Repo.get!(User, giver_id)

    # Reset daily credits if needed
    updated_giver = reset_daily_credits_if_needed(giver)

    # Check if giver has enough credits
    if updated_giver.daily_kudos_credits >= amount do
      case create_kudos(%{giver_id: giver_id, receiver_id: receiver_id, amount: amount}) do
        {:ok, kudos} ->
          # Deduct credits from giver
          new_credits = updated_giver.daily_kudos_credits - amount
          Repo.update!(User.credits_changeset(updated_giver, %{daily_kudos_credits: new_credits}))

          # Increment receiver's kudos count
          receiver = Repo.get!(User, receiver_id)
          Repo.update!(User.kudos_changeset(receiver, %{kudos_count: receiver.kudos_count + amount}))

          {:ok, kudos}
        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, "Insufficient daily kudos credits. You have #{updated_giver.daily_kudos_credits} credits remaining."}
    end
  end

  def give_kudos(_giver_id, _receiver_id, _amount) do
    {:error, "Cannot give kudos to yourself"}
  end

  @doc """
  Check if a user has already given kudos to another user.
  """
  def has_given_kudos?(giver_id, receiver_id) do
    query = from k in Kudos,
            where: k.giver_id == ^giver_id and k.receiver_id == ^receiver_id

    Repo.exists?(query)
  end

  @doc """
  Get kudos count for a user.
  """
  def get_kudos_count(user_id) do
    user = Repo.get!(User, user_id)
    user.kudos_count
  end

  @doc """
  Creates a kudos.
  """
  def create_kudos(attrs \\ %{}) do
    %Kudos{}
    |> Kudos.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets all users who gave kudos to a specific user.
  """
  def get_kudos_givers(receiver_id) do
    query = from k in Kudos,
            where: k.receiver_id == ^receiver_id,
            join: u in User, on: k.giver_id == u.id,
            select: u,
            order_by: [desc: k.inserted_at]

    Repo.all(query)
  end

  @doc """
  Gets all users who received kudos from a specific user.
  """
  def get_kudos_receivers(giver_id) do
    query = from k in Kudos,
            where: k.giver_id == ^giver_id,
            join: u in User, on: k.receiver_id == u.id,
            select: u,
            order_by: [desc: k.inserted_at]

    Repo.all(query)
  end

    @doc """
  Reset daily credits if it's a new day.
  """
  def reset_daily_credits_if_needed(user) do
    today = Date.utc_today()

    if user.last_credits_reset != today do
      changeset = User.credits_changeset(user, %{
        daily_kudos_credits: 100,
        last_credits_reset: today
      })
      Repo.update!(changeset)
    else
      user
    end
  end

  @doc """
  Reset daily credits for all users. This can be run as a daily cron job.
  """
  def reset_all_daily_credits do
    today = Date.utc_today()

    from(u in User,
      where: u.last_credits_reset != ^today or is_nil(u.last_credits_reset)
    )
    |> Repo.update_all(set: [daily_kudos_credits: 100, last_credits_reset: today])
  end
end
