defmodule TeamShoppingWeb.ListsLive do
  use TeamShoppingWeb, :live_view

  alias TeamShopping.Shopping

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center h-full">
      <.action_notification :if={@action_notification} details={@action_notification} />
      <.list_edit
        :if={@live_action in [:new_list, :edit_list]}
        list={@list}
        title={@page_title}
        teams={@teams}
        user={@current_user}
      />
      <.shopping_lists :if={!@action_notification} lists={@lists} user_id={@current_user.id} />
      <.delete_confirmation item={@to_delete} />
    </div>
    """
  end

  attr(:details, :any, required: true)

  defp action_notification(assigns) do
    ~H"""
    <.header>
      <div>
        {@details.message}
        <img class="max-w-20 mx-auto" src={@details.image} />
      </div>
      <:subtitle>{@details.offer}</:subtitle>
      <:actions>
        <.button_link patch={~p"/lists/new"}>{gettext("New List")}</.button_link>
      </:actions>
    </.header>
    """
  end

  attr(:list, :any, required: true)
  attr(:title, :string, required: true)
  attr(:user, :any, required: true)
  attr(:teams, :list, default: [])

  defp list_edit(assigns) do
    ~H"""
    <.modal id="list-modal" show on_cancel={JS.patch(~p"/lists")}>
      <.live_component
        module={TeamShoppingWeb.ListsLive.FormComponent}
        id={(@list && @list.id) || :new}
        title={@title}
        list={@list}
        teams={@teams}
        user={@user}
        patch={~p"/lists"}
      />
    </.modal>
    """
  end

  attr(:lists, :list, required: true)
  attr(:user_id, :any, required: true)

  defp shopping_lists(assigns) do
    ~H"""
    <div class="flex flex-wrap space-x-4 justify-center overflow-y-auto">
      <.shopping_list :for={item <- @lists} list={item} user_id={@user_id} />
      <.new_shopping_list />
    </div>
    """
  end

  attr(:list, :any, required: true)
  attr(:user_id, :any, required: true)

  defp shopping_list(assigns) do
    assigns =
      assign_new(assigns, :modifiable?, fn ->
        Shopping.modifiable?(assigns.list, assigns.user_id)
      end)

    ~H"""
    <div class="flex flex-col items-center w-52 h-72">
      <span>{@list.name}</span>
      <img
        phx-click={JS.navigate(~p"/lists/#{@list}")}
        class="h-52 max-h-[50vh] mx-auto cursor-pointer"
        src={~p"/images/shopping_list.svg"}
      />
      <div class="flex">
        <button
          :if={@modifiable?}
          phx-click={JS.push("delete", value: %{id: @list.id}) |> show_modal("confirm-modal")}
          class="pb-2 px-3 text-black dark:text-white hover:text-zinc-700 dark:hover:text-zinc-300"
        >
          <.icon name="hero-trash-solid" class="h-5 w-5" />
        </button>
        <.link :if={@modifiable?} patch={~p"/lists/#{@list}/edit"} alt="Edit list">
          <.icon name="hero-pencil-square-solid" class="h-5 w-5" />
        </.link>
      </div>
    </div>
    """
  end

  defp new_shopping_list(assigns) do
    ~H"""
    <div
      phx-click={JS.patch(~p"/lists/new")}
      class="flex flex-col items-center justify-center border-2 border-dashed border-zinc-200 dark:border-zinc-600 w-52 h-72 cursor-pointer"
    >
      <.icon name="hero-plus-solid" class="size-16" />
    </div>
    """
  end

  attr(:item, :any, default: nil)

  defp delete_confirmation(assigns) do
    ~H"""
    <.modal id="confirm-modal" show={@item} on_cancel={JS.push("cancel_delete")}>
      <.header>
        {@item && gettext("Really delete '%{name}'?", name: @item.name)}
      </.header>
      <.button
        phx-click={@item && JS.push("confirm_delete") |> hide_modal("confirm-modal")}
        class="mt-2"
      >
        {gettext("Delete")}
      </.button>
    </.modal>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, default_assigns(socket)}
  end

  def handle_params(params, _uri, socket) do
    if connected?(socket) do
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    else
      {:noreply, socket}
    end
  end

  defp apply_action(socket, :lists, _params) do
    socket
    |> assign(:page_title, gettext("Lists"))
    |> assign_lists()
  end

  defp apply_action(socket, :new_list, _params) do
    socket
    |> assign(:page_title, gettext("New List"))
    |> assign_teams()
  end

  defp apply_action(socket, :edit_list, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit List"))
    |> assign(:list, Shopping.get_shopping_list!(id))
    |> assign_teams()
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, to_delete: find_list_by_id(socket, id))}
  end

  def handle_event("confirm_delete", _, socket) do
    if socket.assigns.to_delete do
      Shopping.delete_shopping_list(socket.assigns.to_delete, actor: socket.assigns.current_user)
      |> IO.inspect()
    end

    {:noreply, socket |> assign_lists() |> assign(:list, nil)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, to_delete: nil)}
  end

  defp assign_lists(socket) do
    lists = Shopping.list_shopping_lists!(socket.assigns.current_user.id)

    assign(socket,
      lists: lists,
      action_notification: to_action_notification(lists),
      to_delete: nil
    )
  end

  defp assign_teams(socket) do
    current_user = Ash.load!(socket.assigns.current_user, :teams)

    assign(socket, current_user: current_user, teams: current_user.teams)
  end

  defp to_action_notification([]),
    do: %{
      message: gettext("You don't have a shopping list yet"),
      offer: gettext("Do you want to create one now?"),
      image: ~p"/images/empty_list.svg",
      action: gettext("New Shopping List")
    }

  defp to_action_notification(_), do: nil

  defp default_assigns(socket) do
    assign(socket,
      lists: [],
      action_notification: nil,
      create_form: nil,
      to_delete: nil,
      teams: [],
      list: nil,
      page_title: nil
    )
  end

  defp find_list_by_id(socket, id) do
    # List.first(socket.assigns.lists)
    Enum.find(socket.assigns.lists, &(&1.id == id))
  end
end
