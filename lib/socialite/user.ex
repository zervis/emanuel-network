defmodule Socialite.User do
  use Ecto.Schema
  import Ecto.Changeset

  @genders ["Male", "Female", "Other"]
  @relationship_statuses ["Single", "In a relationship", "Married", "Divorced", "Widowed", "Other"]
  @personality_types ["INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    field :password_hash, :string
    field :avatar, :string
    field :bio, :string
    field :is_active, :boolean, default: true
    field :kudos_count, :integer, default: 0
    field :daily_kudos_credits, :integer, default: 100
    field :last_credits_reset, :date
    field :followers_count, :integer, default: 0
    field :following_count, :integer, default: 0
    field :gender, :string
    field :relationship_status, :string
    field :personality_type, :string
    field :birthdate, :date
    field :age, :integer, virtual: true

    # Physical attributes
    field :height, :integer  # Height in centimeters
    field :weight, :float    # Weight in kilograms

    # Location fields
    field :latitude, :float
    field :longitude, :float
    field :address, :string
    field :city, :string
    field :state, :string
    field :country, :string
    field :postal_code, :string
    # field :location_point, Geo.PostGIS.Geometry  # Temporarily disabled due to PostGIS configuration issues

    # Virtual fields for registration
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    has_many :posts, Socialite.Post
    has_many :comments, Socialite.Comment
    has_many :sent_messages, Socialite.Message, foreign_key: :sender_id
    has_many :received_messages, Socialite.Message, foreign_key: :recipient_id
    has_many :given_kudos, Socialite.Kudos, foreign_key: :giver_id
    has_many :received_kudos, Socialite.Kudos, foreign_key: :receiver_id

    # Follow relationships
    has_many :following_relationships, Socialite.Follow, foreign_key: :follower_id
    has_many :follower_relationships, Socialite.Follow, foreign_key: :followed_id
    has_many :following, through: [:following_relationships, :followed]
    has_many :followers, through: [:follower_relationships, :follower]

    # User pictures
    has_many :user_pictures, Socialite.UserPicture, preload_order: [asc: :order]
    has_one :avatar_picture, Socialite.UserPicture, where: [is_avatar: true]

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name, :email, :password, :password_confirmation, :avatar, :bio, :is_active, :gender, :relationship_status, :personality_type, :birthdate, :height, :weight])
    |> validate_required([:first_name, :last_name, :email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:password, min: 6, message: "must be at least 6 characters")
    |> validate_confirmation(:password, message: "passwords do not match")
    |> validate_inclusion(:gender, @genders, message: "must be a valid gender")
    |> validate_inclusion(:relationship_status, @relationship_statuses, message: "must be a valid relationship status")
    |> validate_inclusion(:personality_type, @personality_types, message: "must be a valid personality type")
    |> validate_birthdate()
    |> validate_height()
    |> validate_weight()
    |> unique_constraint(:email, message: "email already taken")
    |> put_password_hash()
  end

  def location_changeset(user, attrs) do
    user
    |> cast(attrs, [:latitude, :longitude, :address, :city, :state, :country, :postal_code])
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> put_location_point()
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name, :bio, :avatar, :latitude, :longitude, :address, :city, :state, :country, :postal_code, :gender, :relationship_status, :personality_type, :birthdate, :height, :weight])
    |> validate_required([:first_name, :last_name])
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_inclusion(:gender, @genders, message: "must be a valid gender")
    |> validate_inclusion(:relationship_status, @relationship_statuses, message: "must be a valid relationship status")
    |> validate_inclusion(:personality_type, @personality_types, message: "must be a valid personality type")
    |> validate_birthdate()
    |> validate_height()
    |> validate_weight()
    |> put_location_point()
  end

  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
  end

  def kudos_changeset(user, attrs) do
    user
    |> cast(attrs, [:kudos_count])
    |> validate_required([:kudos_count])
  end

  def credits_changeset(user, attrs) do
    user
    |> cast(attrs, [:daily_kudos_credits, :last_credits_reset])
    |> validate_required([:daily_kudos_credits, :last_credits_reset])
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset

  defp put_location_point(%Ecto.Changeset{} = changeset) do
    # Temporarily disabled due to PostGIS configuration issues
    # case {Map.get(changes, :latitude), Map.get(changes, :longitude)} do
    #   {lat, lng} when is_number(lat) and is_number(lng) ->
    #     point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}
    #     put_change(changeset, :location_point, point)
    #   _ ->
    #     changeset
    # end
    changeset
  end

  defp put_location_point(changeset), do: changeset

  defp validate_birthdate(changeset) do
    case get_field(changeset, :birthdate) do
      nil -> changeset
      birthdate ->
        today = Date.utc_today()
        age = Date.diff(today, birthdate) / 365.25

        if age < 13 do
          add_error(changeset, :birthdate, "must be at least 13 years old")
        else
          changeset
        end
    end
  end

  defp validate_height(changeset) do
    case get_field(changeset, :height) do
      nil -> changeset
      height when is_integer(height) ->
        if height >= 50 and height <= 300 do
          changeset
        else
          add_error(changeset, :height, "must be between 50 and 300 cm")
        end
      _ ->
        add_error(changeset, :height, "must be a valid number")
    end
  end

  defp validate_weight(changeset) do
    case get_field(changeset, :weight) do
      nil -> changeset
      weight when is_number(weight) ->
        if weight >= 20.0 and weight <= 500.0 do
          changeset
        else
          add_error(changeset, :weight, "must be between 20 and 500 kg")
        end
      _ ->
        add_error(changeset, :weight, "must be a valid number")
    end
  end

  def age(%__MODULE__{birthdate: birthdate}) when not is_nil(birthdate) do
    today = Date.utc_today()
    trunc(Date.diff(today, birthdate) / 365.25)
  end

  def age(_), do: nil

  def full_name(%__MODULE__{first_name: first_name, last_name: last_name}) do
    "#{first_name} #{last_name}"
  end

  def verify_password(%__MODULE__{password_hash: password_hash}, password) do
    Bcrypt.verify_pass(password, password_hash)
  end

  def full_address(%__MODULE__{} = user) do
    [user.address, user.city, user.state, user.postal_code, user.country]
    |> Enum.filter(&(&1 && String.trim(&1) != ""))
    |> Enum.join(", ")
  end

  @doc """
  Returns the user's avatar URL or a default avatar if none is set.
  """
  def avatar_url(%__MODULE__{avatar: avatar}) when is_binary(avatar) and avatar != "", do: avatar
  def avatar_url(_user), do: "/images/default-avatar.png"

  @doc """
  Returns the default avatar path.
  """
  def default_avatar_path, do: "/images/default-avatar.png"

  def has_location?(%__MODULE__{latitude: lat, longitude: lng}) when not is_nil(lat) and not is_nil(lng), do: true
  def has_location?(_), do: false

  def bmi(%__MODULE__{height: height, weight: weight}) when not is_nil(height) and not is_nil(weight) do
    height_m = height / 100.0
    Float.round(weight / (height_m * height_m), 1)
  end

  def bmi(_), do: nil

  def bmi_category(%__MODULE__{} = user) do
    case bmi(user) do
      nil -> nil
      bmi_value when bmi_value < 18.5 -> "Underweight"
      bmi_value when bmi_value < 25.0 -> "Normal weight"
      bmi_value when bmi_value < 30.0 -> "Overweight"
      _ -> "Obese"
    end
  end
end
