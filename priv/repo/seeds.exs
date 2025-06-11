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

alias Socialite.{Accounts, Content, Messages}
import Ecto.Query

# Create the official Emanuel.Network user first - Bogumił Gargula
bogumiql = Accounts.get_user_by_email("bogumil@emanuel.network") ||
  case Accounts.create_user(%{
    "first_name" => "Bogumił",
    "last_name" => "Gargula",
    "email" => "bogumil@emanuel.network",
    "password" => "emanuel2024!",
    "password_confirmation" => "emanuel2024!"
  }) do
    {:ok, user} ->
      IO.puts("Created official user: #{user.first_name} #{user.last_name} (#{user.email})")
      user
    {:error, _} -> Accounts.get_user_by_email("bogumil@emanuel.network")
  end

# Get existing users or create new ones
john = Accounts.get_user_by_email("john@example.com") ||
  case Accounts.create_user(%{
    "first_name" => "John",
    "last_name" => "Doe",
    "email" => "john@example.com",
    "password" => "password123",
    "password_confirmation" => "password123"
  }) do
    {:ok, user} -> user
    {:error, _} -> Accounts.get_user_by_email("john@example.com")
  end

sarah = Accounts.get_user_by_email("sarah@example.com") ||
  case Accounts.create_user(%{
    "first_name" => "Sarah",
    "last_name" => "Johnson",
    "email" => "sarah@example.com",
    "password" => "password123",
    "password_confirmation" => "password123"
  }) do
    {:ok, user} -> user
    {:error, _} -> Accounts.get_user_by_email("sarah@example.com")
  end

# Create additional users for messaging
mike = Accounts.get_user_by_email("mike@example.com") ||
  case Accounts.create_user(%{
    "first_name" => "Mike",
    "last_name" => "Wilson",
    "email" => "mike@example.com",
    "password" => "password123",
    "password_confirmation" => "password123"
  }) do
    {:ok, user} ->
      IO.puts("Created user: #{user.first_name} #{user.last_name} (#{user.email})")
      user
    {:error, _} -> Accounts.get_user_by_email("mike@example.com")
  end

# Make all users follow Bogumił Gargula by default
all_users = [john, sarah, mike]
Enum.each(all_users, fn user ->
  case Socialite.FollowContext.follow_user(user.id, bogumiql.id) do
    {:ok, _follow} ->
      IO.puts("#{user.first_name} is now following Bogumił Gargula")
    {:error, _} ->
      IO.puts("#{user.first_name} already follows Bogumił Gargula")
  end
end)

# Create Bogumił's official welcome post if it doesn't exist
existing_official_posts = Socialite.Repo.all(from p in Socialite.Post, where: p.user_id == ^bogumiql.id)

if length(existing_official_posts) == 0 do
  {:ok, _official_post} = Content.create_post(%{
    "content" => "🎉 Welcome to Emanuel.Network! 🌟\n\nConnect, share, and grow with our amazing community. Give kudos to show appreciation, follow interesting people, and discover great content every day.\n\n✨ New here? Start by exploring profiles and following people who inspire you!\n\n#EmanuelNetwork #Community #Welcome",
    "user_id" => bogumiql.id
  })

  IO.puts("Created official welcome post by Bogumił Gargula")
end

# Create sample groups for testing
alias Socialite.Groups

# Get some users to be group creators and members
users = Socialite.Repo.all(Socialite.User) |> Enum.take(5)

if length(users) >= 2 do
  # Group 1: Tech Meetup in Warsaw
  {:ok, tech_group} = Groups.create_group(%{
    "name" => "Warsaw Tech Meetup",
    "description" => "Monthly meetups for developers, designers, and tech enthusiasts in Warsaw. Join us for talks, networking, and learning about the latest in technology.",
    "address" => "Warsaw, Poland",
    "lat" => 52.2297,
    "lng" => 21.0122,
    "creator_id" => Enum.at(users, 0).id,
    "is_public" => true
  })

  # Group 2: Book Club
  {:ok, book_group} = Groups.create_group(%{
    "name" => "Warsaw Book Club",
    "description" => "Weekly book discussions and monthly author meetups. Currently reading fiction and non-fiction works by Polish and international authors.",
    "address" => "Warsaw Old Town, Poland",
    "lat" => 52.2485,
    "lng" => 21.0137,
    "creator_id" => Enum.at(users, 1).id,
    "is_public" => true
  })

  # Group 3: Fitness Group
  {:ok, fitness_group} = Groups.create_group(%{
    "name" => "Morning Runners Warsaw",
    "description" => "Join us for daily morning runs around Warsaw's beautiful parks. All fitness levels welcome!",
    "address" => "Łazienki Park, Warsaw",
    "lat" => 52.2148,
    "lng" => 21.0367,
    "creator_id" => Enum.at(users, 2).id,
    "is_public" => true
  })

  # Add some members to groups
  if length(users) >= 4 do
    Groups.join_group(Enum.at(users, 2).id, tech_group.id)
    Groups.join_group(Enum.at(users, 3).id, tech_group.id)
    Groups.join_group(Enum.at(users, 0).id, book_group.id)
    Groups.join_group(Enum.at(users, 3).id, book_group.id)
  end

  # Create some group posts
  Groups.create_group_post(%{
    "content" => "🚀 Excited to announce our next meetup on January 15th! We'll be covering React 18 and the new concurrent features. RSVP in the comments!",
    "user_id" => Enum.at(users, 0).id,
    "group_id" => tech_group.id
  })

  Groups.create_group_post(%{
    "content" => "📚 This week we're discussing 'The Midnight Library' by Matt Haig. What did everyone think about the ending?",
    "user_id" => Enum.at(users, 1).id,
    "group_id" => book_group.id
  })

  Groups.create_group_post(%{
    "content" => "🏃‍♀️ Weather looks great for tomorrow's 7 AM run! Meeting at the main entrance of Łazienki Park. Don't forget your water bottles!",
    "user_id" => Enum.at(users, 2).id,
    "group_id" => fitness_group.id
  })

  # Create some group events
  tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)
  next_week = DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)

  Groups.create_group_event(%{
    "title" => "React 18 Workshop",
    "description" => "Hands-on workshop covering React 18's new concurrent features, automatic batching, and Suspense improvements.",
    "address" => "Google Campus Warsaw, Nowy Świat 6/12",
    "lat" => 52.2319,
    "lng" => 21.0203,
    "start_time" => next_week,
    "end_time" => DateTime.add(next_week, 3, :hour) |> DateTime.truncate(:second),
    "max_attendees" => 30,
    "user_id" => Enum.at(users, 0).id,
    "group_id" => tech_group.id
  })

  Groups.create_group_event(%{
    "title" => "Morning Run Session",
    "description" => "Join us for our regular morning run around Łazienki Park. 5km route, all paces welcome!",
    "address" => "Łazienki Park Main Entrance",
    "lat" => 52.2148,
    "lng" => 21.0367,
    "start_time" => tomorrow,
    "end_time" => DateTime.add(tomorrow, 1, :hour) |> DateTime.truncate(:second),
    "max_attendees" => 15,
    "user_id" => Enum.at(users, 2).id,
    "group_id" => fitness_group.id
  })

  # Create "Bogumil friends" group with all users
  {:ok, bogumil_friends_group} = Groups.create_group(%{
    "name" => "Bogumil friends",
    "description" => "A close-knit group of friends in Warsaw. Join us for casual meetups, good conversations, and exploring the city together!",
    "address" => "Warsaw, Poland",
    "lat" => 52.2297,
    "lng" => 21.0122,
    "creator_id" => bogumiql.id,
    "is_public" => true
  })

  # Add all users to Bogumil friends group
  all_users_including_bogumil = [john, sarah, mike]
  Enum.each(all_users_including_bogumil, fn user ->
    case Groups.join_group(user.id, bogumil_friends_group.id) do
      {:ok, _membership} ->
        IO.puts("#{user.first_name} joined Bogumil friends group")
      {:error, _} ->
        IO.puts("#{user.first_name} is already a member of Bogumil friends group")
    end
  end)

  # Create a welcome post in the Bogumil friends group
  Groups.create_group_post(%{
    "content" => "🎉 Welcome to our friends group! Looking forward to spending more time together and exploring Warsaw. Who's up for coffee this week?",
    "user_id" => bogumiql.id,
    "group_id" => bogumil_friends_group.id
  })

  IO.puts("Created sample groups with posts and events")
else
  IO.puts("Not enough users to create sample groups")
end

# Create sample messages between users
messages_to_create = [
  %{content: "Hey Sarah! How are you doing?", sender_id: john.id, recipient_id: sarah.id},
  %{content: "Hi John! I'm doing great, thanks for asking!", sender_id: sarah.id, recipient_id: john.id},
  %{content: "Would you like to meet up for coffee sometime?", sender_id: john.id, recipient_id: sarah.id},
  %{content: "That sounds wonderful! I'd love to.", sender_id: sarah.id, recipient_id: john.id},
  %{content: "Hey Mike! Welcome to the community!", sender_id: john.id, recipient_id: mike.id},
  %{content: "Thanks John! Great to be here.", sender_id: mike.id, recipient_id: john.id},
  %{content: "Hi Mike! Sarah here. John told me about you.", sender_id: sarah.id, recipient_id: mike.id},
  %{content: "Hi Sarah! Nice to meet you.", sender_id: mike.id, recipient_id: sarah.id}
]

Enum.each(messages_to_create, fn message_attrs ->
  case Messages.create_message(message_attrs) do
    {:ok, message} ->
      IO.puts("Created message: '#{message.content}' from #{message.sender.first_name} to #{message.recipient.first_name}")
    {:error, _changeset} ->
      IO.puts("Message already exists or failed to create")
  end
end)

# Create additional posts if they don't exist
existing_posts = Content.list_posts()
if length(existing_posts) <= 1 do  # Only official post exists
  # Create a test post
  {:ok, post} = Content.create_post(%{
    "content" => "Welcome to Emanuel Network! This is my first post. 🙏",
    "user_id" => john.id
  })

  IO.puts("Created post: #{post.content}")

  # Create a test comment
  {:ok, comment} = Content.create_comment(%{
    "content" => "Great to see you here!",
    "user_id" => sarah.id,
    "post_id" => post.id
  })

  IO.puts("Created comment: #{comment.content}")

  # Create another post
  {:ok, post2} = Content.create_post(%{
    "content" => "Blessed to be part of this amazing community! Looking forward to sharing God's love with all of you. ✨",
    "user_id" => sarah.id
  })

  IO.puts("Created post: #{post2.content}")
end

IO.puts("Database seeded successfully!")
