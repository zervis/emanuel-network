defmodule Socialite.UserPicture do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_pictures" do
    field :url, :string
    field :is_avatar, :boolean, default: false
    field :order, :integer, default: 0

    belongs_to :user, Socialite.User

    timestamps()
  end

  @doc false
  def changeset(user_picture, attrs) do
    user_picture
    |> cast(attrs, [:url, :is_avatar, :order, :user_id])
    |> validate_required([:url, :user_id])
    |> validate_url_or_path()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_url_or_path(changeset) do
    case get_field(changeset, :url) do
      nil -> changeset
      url when is_binary(url) ->
        cond do
          String.starts_with?(url, "http://") or String.starts_with?(url, "https://") ->
            changeset
          String.starts_with?(url, "/uploads/") ->
            changeset
          true ->
            add_error(changeset, :url, "must be a valid URL or upload path")
        end
      _ ->
        add_error(changeset, :url, "must be a string")
    end
  end
end
