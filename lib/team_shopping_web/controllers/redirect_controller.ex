defmodule TeamShoppingWeb.RedirectController do
  use TeamShoppingWeb, :controller

  def redirect_to_lists(conn, _) do
    redirect(conn, to: ~p"/lists")
  end
end
