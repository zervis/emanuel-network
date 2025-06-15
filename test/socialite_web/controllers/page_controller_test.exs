defmodule SocialiteWeb.PageControllerTest do
  use SocialiteWeb.ConnCase

  test "GET / when not logged in shows home page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Emanuel Network"
  end

  test "GET / when logged in redirects to feed", %{conn: conn} do
    # Create a real test user in the database
    {:ok, user} = Socialite.Accounts.create_user(%{
      "first_name" => "Test",
      "last_name" => "User",
      "email" => "test@example.com",
      "password" => "password123456",
      "password_confirmation" => "password123456"
    })

    # Simulate logged in user by setting session and calling the plug
    conn =
      conn
      |> Plug.Test.init_test_session(%{current_user_id: user.id})
      |> SocialiteWeb.Plugs.AssignCurrentUser.call([])

    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/feed"
  end
end
