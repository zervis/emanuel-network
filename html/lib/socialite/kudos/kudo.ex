defmodule Socialite.Kudos.Kudo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "kudos" do
    field :message, :string

    belongs_to :giver, Socialite.Accounts.User, foreign_key: :giver_id
    belongs_to :receiver, Socialite.Accounts.User, foreign_key: :receiver_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(kudo, attrs) do
    kudo
    |> cast(attrs, [:message, :giver_id, :receiver_id])
    |> validate_required([:giver_id, :receiver_id])
    |> validate_length(:message, max: 500)
    |> foreign_key_constraint(:giver_id)
    |> foreign_key_constraint(:receiver_id)
    |> validate_not_self_kudo()
    |> unique_constraint([:giver_id, :receiver_id],
        name: :kudos_giver_id_receiver_id_date_index,
        message: "You can only give one kudo per day to each person")
  end

  defp validate_not_self_kudo(changeset) do
    giver_id = get_change(changeset, :giver_id)
    receiver_id = get_change(changeset, :receiver_id)

    if giver_id && receiver_id && giver_id == receiver_id do
      add_error(changeset, :receiver_id, "You cannot give kudos to yourself")
    else
      changeset
    end
  end
end
