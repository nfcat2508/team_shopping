defmodule TeamShoppingWeb.ListsLive.FormComponent do
  use TeamShoppingWeb, :live_component

  alias TeamShopping.Shopping.List

  @empty_team %{name: "", id: ""}

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
      </.header>
      <.simple_form for={@form} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <.input
          type="text"
          field={@form[:name]}
          label={gettext("Name")}
          maxlength="45"
          phx-debounce="blur"
        />
        <.input type="select" field={@form[:team_id]} label={gettext("Team")} options={@team_opts} />
        <:actions>
          <.button class="mt-2" phx-disable-with={gettext("Saving...")}>
            {gettext("Save")}
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{list: list, teams: teams} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(list)
     |> assign_team_opts(teams, list)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, add_creator_id(params, socket))
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form,
           params: add_creator_id(params, socket)
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("List saved successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(socket, nil) do
    assign(socket, form: List |> AshPhoenix.Form.for_create(:create) |> to_form())
  end

  defp assign_form(socket, %List{} = list) do
    assign(socket,
      form:
        list
        |> AshPhoenix.Form.for_update(:update,
          actor: socket.assigns.user,
          # since Ash.Error.Forbidden.Policy does not implement the `AshPhoenix.FormData.Error
          warn_on_unhandled_errors?: false
        )
        |> to_form()
    )
  end

  defp add_creator_id(%{} = params, socket) do
    Map.put(params, :creator_id, socket.assigns.user.id)
  end

  defp assign_team_opts(socket, teams, nil) do
    assign(socket, team_opts: team_opts(teams))
  end

  defp assign_team_opts(socket, teams, list) do
    assign(socket, team_opts: team_opts(teams) |> select_opt(list.team_id))
  end

  defp team_opts(teams) do
    for team <- teams ++ [@empty_team],
        do: [key: team.name, value: team.id]
  end

  defp select_opt(opts, actual_value) do
    for [key: key, value: value] <- opts,
        do: [key: key, value: value, selected: selected?(value, actual_value)]
  end

  defp selected?(value, nil), do: value == ""
  defp selected?(value, actual_value), do: value == actual_value
end
