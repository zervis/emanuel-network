defmodule Socialite.GroupMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "group_members" do
    field :role, :string, default: "member"
    field :joined_at, :utc_datetime

    belongs_to :user, Socialite.User
    belongs_to :group, Socialite.Group

    timestamps(type: :naive_datetime)
  end

  @doc false
  def changeset(group_member, attrs) do
    group_member
    |> cast(attrs, [:role, :joined_at, :user_id, :group_id])
    |> validate_required([:user_id, :group_id])
    |> validate_inclusion(:role, ["member", "admin", "moderator"])
    |> unique_constraint([:user_id, :group_id])
    |> put_joined_at()
  end

  defp put_joined_at(changeset) do
    case get_field(changeset, :joined_at) do
      nil -> put_change(changeset, :joined_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
