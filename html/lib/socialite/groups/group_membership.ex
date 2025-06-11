defmodule Socialite.Groups.GroupMembership do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "group_memberships" do
    field :role, :string, default: "member"
    field :joined_at, :naive_datetime

    belongs_to :user, Socialite.Accounts.User
    belongs_to :group, Socialite.Groups.Group

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(group_membership, attrs) do
    group_membership
    |> cast(attrs, [:role, :user_id, :group_id])
    |> validate_required([:user_id, :group_id])
    |> validate_inclusion(:role, ["member", "admin", "moderator"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:group_id)
    |> unique_constraint([:user_id, :group_id])
    |> put_joined_at()
  end

  defp put_joined_at(changeset) do
    if get_field(changeset, :joined_at) do
      changeset
    else
      put_change(changeset, :joined_at, NaiveDateTime.utc_now())
    end
  end
end
