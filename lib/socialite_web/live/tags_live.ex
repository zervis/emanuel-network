defmodule SocialiteWeb.TagsLive do
  use SocialiteWeb, :live_view
  alias Socialite.{Tags, Accounts}

  def mount(_params, session, socket) do
    current_user_id = session["current_user_id"]

    if current_user_id do
      current_user = Accounts.get_user!(current_user_id)
      categories = Tags.list_tag_categories()
      user_tags_by_category = Tags.get_user_tags_by_category(current_user_id)

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:categories, categories)
        |> assign(:user_tags_by_category, user_tags_by_category)
        |> assign(:selected_category, nil)
        |> assign(:available_tags, [])
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> assign(:show_add_tag_modal, false)
        |> assign(:new_tag_name, "")
        |> assign(:new_tag_category_id, nil)

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/")}
    end
  end

  def handle_event("select_category", %{"category_id" => category_id}, socket) do
    category_id = String.to_integer(category_id)
    available_tags = Tags.list_tags_by_category(category_id)

    socket =
      socket
      |> assign(:selected_category, category_id)
      |> assign(:available_tags, available_tags)
      |> assign(:search_query, "")
      |> assign(:search_results, [])

    {:noreply, socket}
  end

  def handle_event("search_tags", %{"search" => %{"query" => query}}, socket) do
    search_results = if String.length(query) >= 2 do
      Tags.search_tags(query)
    else
      []
    end

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:search_results, search_results)

    {:noreply, socket}
  end

  def handle_event("add_tag", %{"tag_id" => tag_id}, socket) do
    tag_id = String.to_integer(tag_id)
    current_user_id = socket.assigns.current_user.id

    case Tags.add_user_tag(current_user_id, tag_id) do
      {:ok, _user_tag} ->
        # Refresh user tags
        user_tags_by_category = Tags.get_user_tags_by_category(current_user_id)

        socket =
          socket
          |> assign(:user_tags_by_category, user_tags_by_category)
          |> put_flash(:info, "Tag added successfully!")

        {:noreply, socket}

      {:error, changeset} ->
        error_msg = if changeset.errors[:user_id] do
          "You already have this tag!"
        else
          "Failed to add tag"
        end

        socket = put_flash(socket, :error, error_msg)
        {:noreply, socket}
    end
  end

  def handle_event("remove_tag", %{"tag_id" => tag_id}, socket) do
    tag_id = String.to_integer(tag_id)
    current_user_id = socket.assigns.current_user.id

    case Tags.remove_user_tag(current_user_id, tag_id) do
      {:ok, _} ->
        # Refresh user tags
        user_tags_by_category = Tags.get_user_tags_by_category(current_user_id)

        socket =
          socket
          |> assign(:user_tags_by_category, user_tags_by_category)
          |> put_flash(:info, "Tag removed successfully!")

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to remove tag")
        {:noreply, socket}
    end
  end

  def handle_event("update_proficiency", %{"tag_id" => tag_id, "level" => level}, socket) do
    tag_id = String.to_integer(tag_id)
    level = String.to_integer(level)
    current_user_id = socket.assigns.current_user.id

    case Tags.update_user_tag_proficiency(current_user_id, tag_id, level) do
      {:ok, _} ->
        # Refresh user tags
        user_tags_by_category = Tags.get_user_tags_by_category(current_user_id)

        socket =
          socket
          |> assign(:user_tags_by_category, user_tags_by_category)
          |> put_flash(:info, "Proficiency updated!")

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to update proficiency")
        {:noreply, socket}
    end
  end

  def handle_event("show_add_tag_modal", %{"category_id" => category_id}, socket) do
    category_id = String.to_integer(category_id)

    socket =
      socket
      |> assign(:show_add_tag_modal, true)
      |> assign(:new_tag_category_id, category_id)
      |> assign(:new_tag_name, "")

    {:noreply, socket}
  end

  def handle_event("hide_add_tag_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_add_tag_modal, false)
      |> assign(:new_tag_category_id, nil)
      |> assign(:new_tag_name, "")

    {:noreply, socket}
  end

  def handle_event("create_new_tag", %{"tag" => %{"name" => name}}, socket) do
    category_id = socket.assigns.new_tag_category_id
    current_user_id = socket.assigns.current_user.id

    attrs = %{
      name: String.trim(name),
      category_id: category_id,
      description: "User-created tag"
    }

    case Tags.create_tag(attrs) do
      {:ok, tag} ->
        # Add the new tag to the user
        case Tags.add_user_tag(current_user_id, tag.id) do
          {:ok, _} ->
            # Refresh data
            user_tags_by_category = Tags.get_user_tags_by_category(current_user_id)
            available_tags = if socket.assigns.selected_category == category_id do
              Tags.list_tags_by_category(category_id)
            else
              socket.assigns.available_tags
            end

            socket =
              socket
              |> assign(:user_tags_by_category, user_tags_by_category)
              |> assign(:available_tags, available_tags)
              |> assign(:show_add_tag_modal, false)
              |> assign(:new_tag_category_id, nil)
              |> assign(:new_tag_name, "")
              |> put_flash(:info, "New tag created and added!")

            {:noreply, socket}

          {:error, _} ->
            socket = put_flash(socket, :error, "Tag created but failed to add to your profile")
            {:noreply, socket}
        end

      {:error, changeset} ->
        error_msg = if changeset.errors[:name] do
          "Tag name " <> elem(hd(changeset.errors[:name]), 0)
        else
          "Failed to create tag"
        end

        socket = put_flash(socket, :error, error_msg)
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <!-- main contents -->
      <div class="p-2.5 pt-4">
        <!-- timeline -->
        <div class="lg:flex lg:items-start 2xl:gap-8 gap-6 ml-16" id="js-oversized">

          <!-- Center Content -->
          <div class="flex-1">
            <!-- Header -->
            <div class="mb-8">
              <h1 class="text-3xl font-bold text-gray-900 mb-2">Your Interests & Tags</h1>
              <p class="text-gray-600">Add tags to help others discover your interests and find compatible friends!</p>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
              <!-- Categories Sidebar -->
              <div class="lg:col-span-1">
                <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                  <h2 class="text-xl font-semibold text-gray-900 mb-4">Categories</h2>

                  <!-- Search -->
                  <form phx-change="search_tags" phx-submit="search_tags" class="mb-4">
                    <div class="relative">
                      <input
                        type="text"
                        name="search[query]"
                        value={@search_query}
                        placeholder="Search tags..."
                        class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      />
                      <svg class="absolute left-3 top-2.5 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                      </svg>
                    </div>
                  </form>

                  <!-- Search Results -->
                  <%= if @search_query != "" and length(@search_results) > 0 do %>
                    <div class="mb-4">
                      <h3 class="text-sm font-medium text-gray-700 mb-2">Search Results</h3>
                      <div class="space-y-1">
                        <%= for tag <- @search_results do %>
                          <div class="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
                            <div class="flex items-center space-x-2">
                              <span class="text-xs px-2 py-1 rounded-full bg-blue-100 text-blue-800">
                                <%= tag.category.icon %>
                              </span>
                              <span class="text-sm text-gray-700"><%= tag.name %></span>
                            </div>
                            <button
                              phx-click="add_tag"
                              phx-value-tag_id={tag.id}
                              class="text-xs bg-blue-500 text-white px-2 py-1 rounded hover:bg-blue-600 transition-colors"
                            >
                              Add
                            </button>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <!-- Category List -->
                  <div class="space-y-2">
                    <%= for category <- @categories do %>
                      <button
                        phx-click="select_category"
                        phx-value-category_id={category.id}
                        class={[
                          "w-full text-left p-3 rounded-lg transition-colors border",
                          if(@selected_category == category.id,
                            do: "bg-blue-50 border-blue-200",
                            else: "hover:bg-gray-50 border-transparent")
                        ]}
                      >
                        <div class="flex items-center justify-between">
                          <div class="flex items-center space-x-3">
                            <span class="text-lg"><%= category.icon %></span>
                            <div>
                              <div class="font-medium text-gray-900 capitalize"><%= category.name %></div>
                              <div class="text-xs text-gray-500"><%= category.description %></div>
                            </div>
                          </div>
                          <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
                          </svg>
                        </div>
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>

              <!-- Main Content -->
              <div class="lg:col-span-2">
                <!-- Available Tags -->
                <%= if @selected_category do %>
                  <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
                    <div class="flex flex-col sm:flex-row sm:items-center justify-between mb-4 gap-4">
                      <h2 class="text-xl font-semibold text-gray-900">Available Tags</h2>
                      <button
                        phx-click="show_add_tag_modal"
                        phx-value-category_id={@selected_category}
                        class="bg-green-500 text-white px-4 py-2 rounded-lg hover:bg-green-600 text-sm transition-colors"
                      >
                        + Create New Tag
                      </button>
                    </div>

                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                      <%= for tag <- @available_tags do %>
                        <div class="border border-gray-200 rounded-lg p-3 hover:border-blue-300 transition-colors">
                          <div class="flex items-center justify-between mb-2">
                            <span class="font-medium text-gray-900 text-sm"><%= tag.name %></span>
                            <button
                              phx-click="add_tag"
                              phx-value-tag_id={tag.id}
                              class="text-blue-500 hover:text-blue-700 transition-colors"
                            >
                              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
                              </svg>
                            </button>
                          </div>
                          <%= if tag.description do %>
                            <p class="text-xs text-gray-500 mb-1"><%= tag.description %></p>
                          <% end %>
                          <div class="text-xs text-gray-400">Used by <%= tag.usage_count %> users</div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <!-- Your Tags -->
                <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                  <h2 class="text-xl font-semibold text-gray-900 mb-6">Your Tags</h2>

                  <%= if Enum.empty?(@user_tags_by_category) do %>
                    <div class="text-center py-8">
                      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.99 1.99 0 013 12V7a4 4 0 014-4z"></path>
                      </svg>
                      <h3 class="mt-2 text-sm font-medium text-gray-900">No tags yet</h3>
                      <p class="mt-1 text-sm text-gray-500">Start by selecting a category and adding some tags!</p>
                    </div>
                  <% else %>
                    <div class="space-y-6">
                      <%= for {category, user_tags} <- @user_tags_by_category do %>
                        <div>
                          <div class="flex items-center space-x-2 mb-3">
                            <span class="text-lg"><%= category.icon %></span>
                            <h3 class="text-lg font-medium text-gray-900 capitalize"><%= category.name %></h3>
                            <span class="text-sm text-gray-500">(<%= length(user_tags) %>)</span>
                          </div>

                          <div class="grid grid-cols-1 lg:grid-cols-2 gap-3">
                            <%= for user_tag <- user_tags do %>
                              <div class="border border-gray-200 rounded-lg p-4 hover:shadow-sm transition-shadow">
                                <div class="flex items-center justify-between mb-3">
                                  <span class="font-medium text-gray-900"><%= user_tag.tag.name %></span>
                                  <button
                                    phx-click="remove_tag"
                                    phx-value-tag_id={user_tag.tag.id}
                                    class="text-red-500 hover:text-red-700 transition-colors"
                                    title="Remove tag"
                                  >
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                                    </svg>
                                  </button>
                                </div>

                                <!-- Proficiency Level -->
                                <div>
                                  <label class="text-xs text-gray-500 mb-2 block">Interest Level</label>
                                  <div class="flex space-x-1">
                                    <%= for level <- 1..5 do %>
                                      <button
                                        phx-click="update_proficiency"
                                        phx-value-tag_id={user_tag.tag.id}
                                        phx-value-level={level}
                                        class={[
                                          "w-6 h-6 rounded-full border-2 transition-colors",
                                          if(level <= user_tag.proficiency_level,
                                            do: "bg-yellow-400 border-yellow-400",
                                            else: "border-gray-300 hover:border-gray-400")
                                        ]}
                                        title={"Interest level #{level}"}
                                      >
                                        <span class="sr-only">Level <%= level %></span>
                                      </button>
                                    <% end %>
                                  </div>
                                </div>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Add Tag Modal -->
      <%= if @show_add_tag_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div class="bg-white rounded-lg p-6 w-full max-w-md">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Create New Tag</h3>

            <form phx-submit="create_new_tag">
              <div class="mb-4">
                <label class="block text-sm font-medium text-gray-700 mb-2">Tag Name</label>
                <input
                  type="text"
                  name="tag[name]"
                  value={@new_tag_name}
                  placeholder="Enter tag name..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                />
              </div>

              <div class="flex flex-col sm:flex-row gap-3">
                <button
                  type="submit"
                  class="flex-1 bg-blue-500 text-white py-2 px-4 rounded-lg hover:bg-blue-600 transition-colors"
                >
                  Create Tag
                </button>
                <button
                  type="button"
                  phx-click="hide_add_tag_modal"
                  class="flex-1 bg-gray-300 text-gray-700 py-2 px-4 rounded-lg hover:bg-gray-400 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    """
  end
end
