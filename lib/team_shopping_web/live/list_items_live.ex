defmodule TeamShoppingWeb.ListItemsLive do
  use TeamShoppingWeb, :live_view

  alias TeamShopping.Catalogs
  alias TeamShopping.Catalogs.{Article}
  alias TeamShopping.Shopping
  alias TeamShopping.Shopping.{Events, ListItem}
  alias TeamShopping.Teams

  @empty_member %{name: "", id: ""}

  def render(assigns) do
    ~H"""
    <.nav_bar>
      <.nav_button
        phx-click={JS.patch(~p"/lists/#{@list_id}")}
        active?={@live_action == :list}
        aria-controls="list"
      >
        {gettext("Shopping")}
      </.nav_button>
      <.nav_button
        phx-click={JS.patch(~p"/lists/#{@list_id}/items")}
        active?={@live_action == :items}
        aria-controls="articles"
      >
        {gettext("Articles")}
      </.nav_button>
    </.nav_bar>
    <.tab_bar>
      <:view_selections>
        <.search />
        <div :if={@live_action == :list}>
          <.tab_button phx-click="show_open_items" active={@active_tab == :open}>
            {gettext("Open")}
          </.tab_button>
          <.tab_button phx-click="show_done_items" active={@active_tab == :done}>
            {gettext("Done")}
          </.tab_button>
          <.tab_option phx-click="toggle_show_my_items_only" active={@show_my_items_only}>
            {gettext("My items only")}
          </.tab_option>
        </div>
      </:view_selections>
    </.tab_bar>
    <div :if={@live_action == :list} class="overflow-y-auto">
      <.item_actions />
      <.item_form form={@item_form} member_opts={@member_opts} />
      <.delete_confirmation item={@to_delete} />
      <.item_list items={@items} member_opts={@member_opts} member_map={to_member_map(@member_opts)} />
    </div>
    <div :if={@live_action == :items} class="overflow-y-auto">
      <.article_actions />
      <.article_form form={@article_form} member_opts={@member_opts} />
      <.delete_article_confirmation article={@article_to_delete} />
      <.article_list
        articles={@articles}
        member_opts={@member_opts}
        member_map={to_member_map(@member_opts)}
      />
    </div>
    """
  end

  slot(:inner_block, required: true)

  defp nav_bar(assigns) do
    ~H"""
    <nav class="flex min-h-10 border-b-2 rounded border-zinc-100 dark:border-zinc-700">
      {render_slot(@inner_block)}
    </nav>
    """
  end

  attr(:active?, :boolean, default: false)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  defp nav_button(assigns) do
    ~H"""
    <button
      {@rest}
      class={[
        "flex-1 w-1/3 uppercase font-extrabold font-sans text-sm",
        (@active? && "border-b-4 rounded-sm") || "pb-1"
      ]}
      disabled={@active?}
      aria-selected={@active?}
      role="tab"
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr(:active?, :boolean, default: false)

  defp search(assigns) do
    ~H"""
    <form phx-change="filter" class="flex justify-content justify-items">
      <button type="reset"><.icon name="hero-x-circle" class="size-6" /></button>
      <input
        id="searchInput"
        class="block w-full rounded-lg dark:bg-black text-zinc-900 dark:text-zinc-100 focus:ring-0 text-sm border-zinc-300 dark:border-zinc-700 focus:border-zinc-400 dark:focus:border-zinc-600"
        type="text"
        name="substring"
        value=""
        minlength="3"
        maxlength="20"
        placeholder={gettext("filter by name")}
        phx-hook="BlurOnEnter"
      />
      <input type="submit" disabled class="hidden" aria-hidden="true" />
    </form>
    """
  end

  slot(:view_selections, required: true)

  defp tab_bar(assigns) do
    ~H"""
    <div class="w-full">
      <div class="flex flex-wrap -mb-px justify-center border-b border-zinc-100 dark:border-zinc-700 mb-4 items-center">
        {render_slot(@view_selections)}
      </div>
    </div>
    """
  end

  attr(:active, :boolean, default: false)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  defp tab_button(assigns) do
    ~H"""
    <button
      {@rest}
      class={[
        "mr-2 inline-block hover:border-zinc-300 rounded-t-lg py-4 px-4 text-sm font-medium text-center border-transparent border-b-2 hover:text-zinc-900 dark:hover:text-zinc-100",
        (@active && "text-zinc-900 dark:text-zinc-100 border-zinc-300") ||
          "text-zinc-700 dark:text-zinc-300"
      ]}
      type="button"
      aria-controls="Open"
      aria-selected={(@active && "true") || "false"}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr(:active, :boolean, default: false)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  defp tab_option(assigns) do
    ~H"""
    <button
      {@rest}
      class={[
        "mr-2 inline-block rounded-t-lg py-4 px-4 text-sm font-medium text-center border",
        (@active && "text-zinc-900 dark:text-zinc-100 border-zinc-300 dark:border-zinc-500") ||
          "text-zinc-700 dark:text-zinc-300 border-zinc-100 dark:border-zinc-700"
      ]}
      type="button"
      aria-selected={(@active && "true") || "false"}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp item_actions(assigns) do
    ~H"""
    <div class="sticky top-5 z-50 flex flex-row-reverse">
      <.button phx-click={JS.push("new_item") |> show_modal("new-item-modal")}>
        {gettext("Add Item")}
      </.button>
    </div>
    """
  end

  defp article_actions(assigns) do
    ~H"""
    <div class="sticky top-4 z-50 flex flex-row-reverse">
      <.button phx-click={JS.push("new_article") |> show_modal("new-article-modal")}>
        {gettext("Add Article")}
      </.button>
    </div>
    """
  end

  attr(:items, :list, required: true)
  attr(:member_opts, :list, default: [])
  attr(:member_map, :map, default: %{})

  defp item_list(assigns) do
    ~H"""
    <div class="flex flex-wrap justify-center">
      <.item :for={item <- @items} item={item} member_opts={@member_opts} member_map={@member_map} />
    </div>
    """
  end

  defp to_member_map(member_opts) do
    member_opts
    |> Enum.map(fn [key: name, value: id] -> {id, name} end)
    |> Map.new()
  end

  attr(:articles, :list, required: true)
  attr(:member_opts, :list, default: [])
  attr(:member_map, :map, default: %{})

  defp article_list(assigns) do
    ~H"""
    <div class="flex flex-col space-y-4 overflow-hidden">
      <div
        :for={article <- @articles}
        class="grid grid-cols-3 border border-zinc-100 dark:border-zinc-700"
      >
        <div class="col-span-2 text-center">
          <div class="flex">
            <.member_select
              active_member_id={article.assigned_member_id}
              member_opts={@member_opts}
              member_map={@member_map}
            />
            <div class="flex-grow">
              <div>{article.name}</div>
              <div :if={article.quantity}>{print_quantity(article)}</div>
            </div>
          </div>
        </div>
        <div class="flex items-center justify-evenly">
          <button phx-click={
            JS.push("add_to_list", value: to_map(article)) |> JS.transition("text-green-500")
          }>
            <.icon name="hero-plus-circle-solid" class="p-2 size-8" />
          </button>
          <button phx-click={
            JS.push("select_article", value: %{id: article.id}) |> show_modal("new-article-modal")
          }>
            <.icon name="hero-pencil-square-solid" class="p-2 size-8" />
          </button>
          <button phx-click={
            JS.push("delete_article", value: %{id: article.id, name: article.name})
            |> show_modal("confirm-article-modal")
          }>
            <.icon name="hero-trash-solid" class="p-2 size-8" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr(:item, :any, required: true)
  attr(:actions, :list, default: [:delete, :check, :edit])
  attr(:member_opts, :list, default: [])
  attr(:member_map, :map, default: %{})

  defp item(assigns) do
    ~H"""
    <.box>
      <div class="flex flex-col h-full relative">
        <div
          phx-click={JS.push("select_item", value: %{id: @item.id}) |> show_modal("new-item-modal")}
          class="cursor-pointer h-2/3 w-full flex flex-col justify-center items-center text-center"
        >
          <div>{print_name(@item.name)}</div>
          <div :if={@item.quantity} class="text-xs">{print_quantity(@item)}</div>
        </div>
        <.action_bar
          actions={@actions}
          item={@item}
          member_map={@member_map}
          member_opts={@member_opts}
        />
      </div>
    </.box>
    """
  end

  defp print_name(name) do
    name.string
    |> String.split()
    |> Enum.map(&abbreviate/1)
    |> Enum.join(" ")
  end

  defp abbreviate(word) do
    word
    |> String.split_at(13)
    |> case do
      {string_to_print, ""} -> string_to_print
      {string_to_print, _} -> "#{string_to_print}."
    end
  end

  defp print_quantity(%{quantity: quantity, quantity_unit: unit}) do
    "#{quantity} #{unit || "x"}"
  end

  attr(:actions, :list, default: [])
  attr(:item, :any, required: true)
  attr(:member_map, :map, default: %{})
  attr(:member_opts, :list, default: [])

  defp action_bar(assigns) do
    ~H"""
    <div class="bg-zinc-200 dark:bg-zinc-800 h-1/3 min-h-10 w-full absolute bottom-0 flex justify-between items-center text-center">
      <button phx-click={
        JS.push("delete", value: %{id: @item.id, name: @item.name}) |> show_modal("confirm-modal")
      }>
        <.icon name="hero-trash-solid" class="size-5" />
      </button>
      <.member_select
        active_member_id={@item.assigned_member_id}
        member_map={@member_map}
        member_opts={@member_opts}
      />

      <button :if={@item.status == :open} phx-click="clear" phx-value-id={@item.id}>
        <.icon name="hero-check-circle" class="size-10" />
      </button>
      <button :if={@item.status == :cleared} phx-click="reopen" phx-value-id={@item.id}>
        <.icon name="hero-check-circle-solid" class="size-10 text-green-500" />
      </button>
    </div>
    """
  end

  attr(:active_member_id, :string, default: nil)
  attr(:member_map, :map, default: %{})
  attr(:member_opts, :list, default: [])

  defp member_select(assigns) do
    ~H"""
    <div class="rounded-full border size-8 border-2 border-black dark:border-white content-center text-xs">
      {short_name(@active_member_id, @member_map)}
    </div>
    """
  end

  defp short_name(member_id, member_map) do
    member_map
    |> Map.get(member_id, "???")
    |> String.slice(0, 3)
  end

  attr(:item, :any, default: nil)

  defp delete_confirmation(assigns) do
    ~H"""
    <.modal id="confirm-modal">
      <.header>
        {@item && gettext("Really delete '%{name}'?", name: @item["name"])}
      </.header>
      <.button
        phx-click={
          @item && JS.push("confirm_delete", value: %{id: @item["id"]}) |> hide_modal("confirm-modal")
        }
        class="mt-2"
      >
        {gettext("Delete")}
      </.button>
    </.modal>
    """
  end

  attr(:article, :any, default: nil)

  defp delete_article_confirmation(assigns) do
    ~H"""
    <.modal id="confirm-article-modal">
      <.header>
        {@article && gettext("Really delete '%{name}'?", name: @article["name"])}
      </.header>
      <.button
        phx-click={
          @article &&
            JS.push("confirm_article_delete", value: %{id: @article["id"]})
            |> hide_modal("confirm-article-modal")
        }
        class="mt-2"
      >
        {gettext("Delete")}
      </.button>
    </.modal>
    """
  end

  slot(:inner_block, required: true)

  defp box(assigns) do
    ~H"""
    <div class="h-[20vh] min-h-32 w-1/5 min-w-32 border border-zinc-100 dark:border-zinc-700 hover:border-zinc-300 dark:hover:border-zinc-500 my-4 ml-2 mr-2">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:form, :any, required: true)
  attr(:member_opts, :list, default: [])

  defp item_form(assigns) do
    ~H"""
    <.modal id="new-item-modal">
      <.simple_form :if={@form} for={@form} phx-change="validate" phx-submit="save">
        <.input
          type="text"
          field={@form[:name]}
          label={gettext("Name")}
          maxlength="45"
          phx-debounce="blur"
        />
        <div class="flex space-x-4">
          <.input
            type="text"
            inputmode="numeric"
            pattern="\d*"
            field={@form[:quantity]}
            label={gettext("Quantity")}
            phx-debounce="blur"
          />
          <.input
            type="select"
            options={["", "kg", "g", "mg", "l", "ml"]}
            field={@form[:quantity_unit]}
            fit_content
            label={gettext("Unit")}
            phx-debounce="blur"
          />
        </div>
        <.input
          :if={@member_opts && @member_opts != []}
          type="select"
          field={@form[:assigned_member_id]}
          label={gettext("Assigned to")}
          options={@member_opts}
        />
        <.input
          type="text"
          inputmode="numeric"
          pattern="\d*"
          field={@form[:order]}
          label={gettext("Position")}
          maxlength="3"
          phx-debounce="blur"
        />
        <:actions>
          <.button class="mt-2" phx-click={hide_modal("new-item-modal")}>
            {gettext("Save")}
          </.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

  attr(:form, :any, required: true)
  attr(:member_opts, :list, default: [])

  defp article_form(assigns) do
    ~H"""
    <.modal id="new-article-modal">
      <.simple_form :if={@form} for={@form} phx-change="validate_article" phx-submit="save_article">
        <.input
          type="text"
          field={@form[:name]}
          label={gettext("Name")}
          maxlength="45"
          phx-debounce="blur"
        />
        <div class="flex space-x-4">
          <.input
            type="text"
            inputmode="numeric"
            pattern="\d*"
            field={@form[:quantity]}
            label={gettext("Quantity")}
            phx-debounce="blur"
          />
          <.input
            type="select"
            options={["", "kg", "g", "mg", "l", "ml"]}
            field={@form[:quantity_unit]}
            fit_content
            label={gettext("Unit")}
            phx-debounce="blur"
          />
        </div>
        <.input
          :if={@member_opts && @member_opts != []}
          type="select"
          field={@form[:assigned_member_id]}
          label={gettext("Assigned to")}
          options={@member_opts}
        />
        <.input
          type="text"
          inputmode="numeric"
          pattern="\d*"
          field={@form[:order]}
          label={gettext("Position")}
          maxlength="3"
          phx-debounce="blur"
        />
        <:actions>
          <.button class="mt-2" phx-click={hide_modal("new-article-modal")}>
            {gettext("Save")}
          </.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

  def mount(%{"id" => list_id}, _session, socket) do
    socket = default_assigns(socket, list_id)

    if connected?(socket) do
      Shopping.subscribe_to_shopping_list(list_id)
    end

    {:ok, socket}
  end

  def handle_params(%{"id" => _list_id}, _uri, socket) do
    socket =
      if connected?(socket) do
        socket = assign_member_opts(socket)

        case socket.assigns.live_action do
          :list ->
            socket
            |> assign_items()
            |> assign_member_id()
            |> assign_create_form()

          :items ->
            socket
            |> assign_catalog_id()
            |> assign_articles()
            |> assign_create_article_form()
        end
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("new_item", _params, socket) do
    {:noreply, assign_create_form(socket)}
  end

  def handle_event("new_article", _params, socket) do
    {:noreply, assign_create_article_form(socket)}
  end

  def handle_event("select_item", %{"id" => id}, socket) do
    id
    |> Shopping.get_item()
    |> case do
      {:ok, item} -> {:noreply, assign_update_form(socket, item)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("select_article", %{"id" => id}, socket) do
    id
    |> Catalogs.get_article()
    |> case do
      {:ok, article} -> {:noreply, assign_update_article_form(socket, article)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("save", %{"form" => form_params}, socket) do
    socket.assigns.item_form
    |> AshPhoenix.Form.submit(params: add_list_id(form_params, socket))
    |> case do
      {:ok, _item} ->
        {:noreply, socket |> assign_items() |> assign_create_form()}

      {:error, form} ->
        {:noreply, assign(socket, item_form: form)}
    end
  end

  def handle_event("save_article", %{"form" => form_params}, socket) do
    socket.assigns.article_form
    |> AshPhoenix.Form.submit(params: add_catalog_id(form_params, socket))
    |> case do
      {:ok, _article} ->
        {:noreply, socket |> assign_articles() |> assign(show_article_form: false)}

      {:error, form} ->
        {:noreply, assign(socket, article_form: form)}
    end
  end

  def handle_event("validate", %{"form" => form_params}, socket) do
    item_form =
      form_params
      |> add_list_id(socket)
      |> (&AshPhoenix.Form.validate(socket.assigns.item_form, &1)).()

    {:noreply, assign(socket, item_form: item_form)}
  end

  def handle_event("validate_article", %{"form" => form_params}, socket) do
    article_form =
      form_params
      |> add_catalog_id(socket)
      |> (&AshPhoenix.Form.validate(socket.assigns.article_form, &1)).()

    {:noreply, assign(socket, article_form: article_form)}
  end

  def handle_event("delete", %{"id" => _id, "name" => _name} = to_delete, socket) do
    {:noreply, assign(socket, to_delete: to_delete)}
  end

  def handle_event("delete_article", %{"id" => _id, "name" => _name} = to_delete, socket) do
    {:noreply, assign(socket, article_to_delete: to_delete)}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    Shopping.delete_item(id)

    {:noreply, assign(socket, to_delete: nil)}
  end

  def handle_event("confirm_article_delete", %{"id" => id}, socket) do
    Catalogs.delete_article(id)

    {:noreply, socket |> assign_articles() |> assign(article_to_delete: nil)}
  end

  def handle_event("clear", %{"id" => id}, socket) do
    Shopping.clear_item(id)

    {:noreply, socket}
  end

  def handle_event("reopen", %{"id" => id}, socket) do
    Shopping.reopen_item(id)

    {:noreply, socket}
  end

  def handle_event("show_open_items", _params, socket) do
    {:noreply, socket |> assign_active(:open) |> assign_items()}
  end

  def handle_event("show_done_items", _params, socket) do
    {:noreply, socket |> assign_active(:done) |> assign_items()}
  end

  def handle_event("toggle_show_my_items_only", _params, socket) do
    {:noreply, socket |> toggle_show_my_items_only() |> assign_items()}
  end

  def handle_event("add_to_list", params, socket) do
    Shopping.create_item!(socket.assigns.list_id, Map.drop(params, ["value"]))
    {:noreply, socket}
  end

  def handle_event("filter", %{"substring" => ""}, socket) do
    current_substring_length =
      socket.assigns.filter |> Map.get(:name_substring, "") |> String.length()

    if current_substring_length < 3 do
      {:noreply, socket}
    else
      socket = assign(socket, filter: Map.put(socket.assigns.filter, :name_substring, nil))

      socket.assigns.live_action
      |> case do
        :items -> assign_articles(socket)
        :list -> assign_items(socket)
      end
      |> (&{:noreply, &1}).()
    end
  end

  def handle_event("filter", %{"substring" => substring}, socket) do
    if String.length(substring) < 3 do
      {:noreply, socket}
    else
      socket = assign(socket, filter: Map.put(socket.assigns.filter, :name_substring, substring))

      socket.assigns.live_action
      |> case do
        :items -> assign_articles(socket)
        :list -> assign_items(socket)
      end
      |> (&{:noreply, &1}).()
    end
  end

  def handle_info({ListItem, %Events.ItemAdded{item: _item}}, socket) do
    {:noreply, assign_items(socket)}
  end

  def handle_info({ListItem, %Events.ItemDeleted{item_id: _item_id}}, socket) do
    {:noreply, assign_items(socket)}
  end

  def handle_info({ListItem, %Events.ItemCleared{item_id: _item_id}}, socket) do
    {:noreply, assign_items(socket)}
  end

  def handle_info({ListItem, %Events.ItemReopened{item_id: _item_id}}, socket) do
    {:noreply, assign_items(socket)}
  end

  def handle_info({ListItem, %Events.ItemUpdated{item: _item}}, socket) do
    {:noreply, assign_items(socket)}
  end

  defp add_list_id(%{} = params, socket), do: Map.put(params, :list_id, socket.assigns.list_id)

  defp add_catalog_id(%{} = params, socket),
    do: Map.put(params, :catalog_id, socket.assigns.catalog_id)

  defp assign_items(socket) do
    items =
      socket
      |> list_items()
      |> filter_by_options(socket)

    assign(socket, items: items)
  end

  defp list_items(%{assigns: %{active_tab: :open, list_id: list_id, filter: filter}} = socket) do
    socket = assign(socket, filter: Map.put(filter, :status, :open))

    list_id
    |> Shopping.filter_items(socket.assigns.filter)
    |> case do
      {:ok, items} -> items
      _ -> socket.assigns.items
    end
  end

  defp list_items(%{assigns: %{active_tab: :done, list_id: list_id, filter: filter}} = socket) do
    socket = assign(socket, filter: Map.put(filter, :status, :cleared))

    list_id
    |> Shopping.filter_items(socket.assigns.filter)
    |> case do
      {:ok, items} -> items
      _ -> socket.assigns.items
    end
  end

  defp filter_by_options(items, %{assigns: %{show_my_items_only: true}} = socket) do
    Enum.filter(
      items,
      &(is_nil(&1.assigned_member_id) || &1.assigned_member_id == socket.assigns.member_id)
    )
  end

  defp filter_by_options(items, _socket) do
    items
  end

  defp assign_create_form(socket) do
    assign(socket,
      item_form: ListItem |> AshPhoenix.Form.for_create(:create) |> to_form()
    )
    |> assign_member_opts()
  end

  defp assign_create_article_form(socket) do
    assign(socket,
      article_form: Article |> AshPhoenix.Form.for_create(:create) |> to_form()
    )
    |> assign_member_opts()
  end

  defp assign_update_form(socket, item) do
    assign(socket,
      item_form: item |> AshPhoenix.Form.for_update(:update) |> to_form()
    )
    |> assign_member_opts()
  end

  defp assign_update_article_form(socket, article) do
    assign(socket,
      article_form: article |> AshPhoenix.Form.for_update(:update) |> to_form()
    )
    |> assign_member_opts()
  end

  defp assign_active(socket, active_tab) do
    assign(socket, active_tab: active_tab)
  end

  defp assign_member_opts(socket) do
    if socket.assigns.member_opts != [] do
      socket
    else
      assign(socket, member_opts: member_opts(team_members(socket)))
    end
  end

  defp team_members(socket) do
    with {:ok, list} <- Shopping.get_shopping_list(socket.assigns.list_id),
         team_id when not is_nil(team_id) <- list.team_id do
      Teams.team_members!(team_id)
    else
      _ -> []
    end
  end

  defp assign_member_id(socket) do
    socket
    |> team_members()
    |> Enum.find(&(&1.user_id == socket.assigns.current_user.id))
    |> case do
      nil -> socket
      member -> assign(socket, member_id: member.id)
    end
  end

  defp toggle_show_my_items_only(socket) do
    assign(socket, show_my_items_only: toggle(socket.assigns.show_my_items_only))
  end

  defp default_assigns(socket, list_id) do
    assign(socket,
      list_id: list_id,
      member_id: nil,
      member_opts: [],
      items: [],
      item_form: nil,
      to_delete: nil,
      active_tab: :open,
      show_my_items_only: false,
      catalog_id: nil,
      articles: [],
      article_form: nil,
      article_to_delete: nil,
      filter: %{status: :open}
    )
  end

  defp toggle(false), do: true

  defp toggle(true), do: false

  defp member_opts([]), do: []

  defp member_opts(members) do
    for member <- [@empty_member | members],
        do: [key: member.name, value: member.id]
  end

  defp assign_catalog_id(%{assigns: %{current_user: user}} = socket) do
    user.id
    |> Catalogs.list_catalogs!()
    |> case do
      [] ->
        Catalogs.create_catalog!(user.id, %{name: "Catalog"})

      [catalog | _other] ->
        catalog
    end
    |> (&assign(socket, catalog_id: &1.id)).()
  end

  defp assign_articles(%{assigns: %{catalog_id: catalog_id, filter: filter}} = socket) do
    if filter[:name_substring] do
      catalog_id
      |> Catalogs.find_articles_containing(filter.name_substring)
      |> case do
        {:ok, articles} -> assign(socket, articles: articles)
        _ -> socket
      end
    else
      assign(socket, articles: Catalogs.list_articles!(catalog_id))
    end
  end

  defp to_map(article) do
    article
    |> Map.from_struct()
    |> Map.filter(fn {key, _val} ->
      key in [:name, :quantity, :quantity_unit, :order, :assigned_member_id]
    end)
  end
end
