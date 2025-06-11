defmodule Socialite.Kudos do
  @moduledoc """
  The Kudos context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.Kudos.Kudo
  alias Socialite.Accounts.User

  @doc """
  Returns the list of kudos.
  """
  def list_kudos do
    Repo.all(Kudo)
  end

  @doc """
  Gets a single kudo.
  """
  def get_kudo!(id), do: Repo.get!(Kudo, id)

  @doc """
  Creates a kudo and updates user kudos counts.
  """
  def create_kudo(attrs \\ %{}) do
    Repo.transaction(fn ->
      with {:ok, kudo} <- %Kudo{}
                          |> Kudo.changeset(attrs)
                          |> Repo.insert(),
           {:ok, _giver} <- decrement_daily_kudos(kudo.giver_id),
           {:ok, _receiver} <- increment_kudos_count(kudo.receiver_id) do
        kudo
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Deletes a kudo.
  """
  def delete_kudo(%Kudo{} = kudo) do
    Repo.delete(kudo)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking kudo changes.
  """
  def change_kudo(%Kudo{} = kudo, attrs \\ %{}) do
    Kudo.changeset(kudo, attrs)
  end

  @doc """
  Checks if a user can give kudos to another user today.
  """
  def can_give_kudo?(giver_id, receiver_id) do
    today = Date.utc_today()

    # Check if giver has daily kudos left
    giver = Repo.get!(User, giver_id)

    # Check if already gave kudo to this user today
    existing_kudo =
      from(k in Kudo,
        where: k.giver_id == ^giver_id and
               k.receiver_id == ^receiver_id and
               fragment("date(?)", k.inserted_at) == ^today)
      |> Repo.one()

    giver.daily_kudos > 0 && is_nil(existing_kudo) && giver_id != receiver_id
  end

  @doc """
  Gets kudos received by a user.
  """
  def get_kudos_received(user_id) do
    from(k in Kudo,
      where: k.receiver_id == ^user_id,
      preload: [:giver],
      order_by: [desc: k.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets kudos given by a user.
  """
  def get_kudos_given(user_id) do
    from(k in Kudo,
      where: k.giver_id == ^user_id,
      preload: [:receiver],
      order_by: [desc: k.inserted_at])
    |> Repo.all()
  end

  defp decrement_daily_kudos(user_id) do
    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all(inc: [daily_kudos: -1])

    {:ok, Repo.get!(User, user_id)}
  end

  defp increment_kudos_count(user_id) do
    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all(inc: [kudos_count: 1])

    {:ok, Repo.get!(User, user_id)}
  end
end
