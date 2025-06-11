# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Socialite.Repo.insert!(%Socialite.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Socialite.Accounts
alias Socialite.Kudos

# Create sample users
users = [
  %{
    email: "alice@example.com",
    username: "alice_wonder",
    first_name: "Alice",
    last_name: "Wonder",
    bio: "Curious about everything! Love exploring new ideas and meeting people.",
    password: "password123",
    password_confirmation: "password123"
  },
  %{
    email: "bob@example.com",
    username: "bob_builder",
    first_name: "Bob",
    last_name: "Builder",
    bio: "Building amazing things, one brick at a time.",
    password: "password123",
    password_confirmation: "password123"
  },
  %{
    email: "charlie@example.com",
    username: "charlie_dev",
    first_name: "Charlie",
    last_name: "Developer",
    bio: "Full-stack developer passionate about clean code and user experience.",
    password: "password123",
    password_confirmation: "password123"
  },
  %{
    email: "diana@example.com",
    username: "diana_artist",
    first_name: "Diana",
    last_name: "Artist",
    bio: "Digital artist and designer. Creating beautiful things every day.",
    password: "password123",
    password_confirmation: "password123"
  },
  %{
    email: "eve@example.com",
    username: "eve_explorer",
    first_name: "Eve",
    last_name: "Explorer",
    bio: "Adventure seeker and travel enthusiast. Always ready for the next journey!",
    password: "password123",
    password_confirmation: "password123"
  }
]

IO.puts("Creating users...")

created_users =
  Enum.map(users, fn user_attrs ->
    case Accounts.get_user_by_email(user_attrs.email) do
      nil ->
        {:ok, user} = Accounts.create_user(user_attrs)
        IO.puts("Created user: #{user.username}")
        user

      existing_user ->
        IO.puts("User already exists: #{existing_user.username}")
        existing_user
    end
  end)

# Give some initial kudos between users
IO.puts("Creating sample kudos...")

kudo_pairs = [
  {0, 1, "Great work on your latest project!"},
  {0, 2, "Thanks for helping me with the code review."},
  {1, 0, "Love your positive attitude!"},
  {1, 3, "Your designs are absolutely stunning!"},
  {2, 1, "Excellent problem-solving skills."},
  {2, 4, "Your travel stories are inspiring!"},
  {3, 0, "Always so helpful and kind."},
  {3, 2, "Clean code master!"},
  {4, 1, "Your building projects are amazing."},
  {4, 3, "Beautiful artwork as always!"}
]

Enum.each(kudo_pairs, fn {giver_idx, receiver_idx, message} ->
  giver = Enum.at(created_users, giver_idx)
  receiver = Enum.at(created_users, receiver_idx)

  case Kudos.create_kudo(%{
    giver_id: giver.id,
    receiver_id: receiver.id,
    message: message
  }) do
    {:ok, _kudo} ->
      IO.puts("Created kudo from #{giver.username} to #{receiver.username}")

    {:error, _changeset} ->
      IO.puts("Failed to create kudo from #{giver.username} to #{receiver.username}")
  end
end)

IO.puts("Seed data created successfully!")
IO.puts("You can now run: mix phx.server")
