defmodule Socialite.Kudos do
  use Ecto.Schema
  import Ecto.Changeset

  schema "kudos" do
    belongs_to :giver, Socialite.User
    belongs_to :receiver, Socialite.User
    field :amount, :integer, default: 1

    timestamps()
  end

  def changeset(kudos, attrs) do
    kudos
    |> cast(attrs, [:giver_id, :receiver_id, :amount])
    |> validate_required([:giver_id, :receiver_id, :amount])
    |> validate_number(:amount, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_different_users()
  end

  defp validate_different_users(changeset) do
    giver_id = get_change(changeset, :giver_id)
    receiver_id = get_change(changeset, :receiver_id)

    if giver_id && receiver_id && giver_id == receiver_id do
      add_error(changeset, :receiver_id, "You cannot give kudos to yourself")
    else
      changeset
    end
  end
end
