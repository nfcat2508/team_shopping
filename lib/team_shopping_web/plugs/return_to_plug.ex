defmodule TeamShoppingWeb.ReturnToPlug do
  use TeamShoppingWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  def init(default), do: default

  def call(conn, _default) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> maybe_store_return_to()
      |> redirect(to: ~p"/sign-in")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end
