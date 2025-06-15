# Home Page Redirect Feature

## Overview
The home page now automatically redirects logged-in users to the feed page for a better user experience.

## Implementation
- **File Modified**: `lib/socialite_web/controllers/page_controller.ex`
- **Function**: `home/2`

## Behavior
- **Not Logged In**: Shows the home page with login/registration forms
- **Logged In**: Automatically redirects to `/feed`

## Code Changes
```elixir
def home(conn, _params) do
  # Check if user is already logged in using the assigned current_user
  current_user = conn.assigns[:current_user]
  
  if current_user do
    # User is logged in, redirect to feed
    redirect(conn, to: ~p"/feed")
  else
    # User is not logged in, show home page
    render(conn, :home)
  end
end
```

## Testing
- Added comprehensive tests in `test/socialite_web/controllers/page_controller_test.exs`
- Tests cover both logged-in and not-logged-in scenarios
- All tests pass successfully

## Benefits
1. **Better UX**: Logged-in users don't see the login page unnecessarily
2. **Faster Navigation**: Direct access to the main application content
3. **Consistent Behavior**: Matches common social media platform patterns

## Usage
No changes needed for existing users. The redirect happens automatically when visiting the root URL (`/`) while logged in. 