defmodule TeamShoppingWeb.ReturnToPlugTest do
  use TeamShoppingWeb.ConnCase, async: true

  alias TeamShoppingWeb.ReturnToPlug

  @opts ReturnToPlug.init([])

  setup %{conn: conn} do
    %{conn: init_test_session(conn, %{})}
  end

  test "redirects if user is not authenticated", %{conn: conn} do
    conn = ReturnToPlug.call(conn, @opts)

    assert conn.halted
    assert redirected_to(conn) == ~p"/sign-in"
  end

  test "stores the path to redirect to on GET", %{conn: conn} do
    halted_conn =
      %{conn | path_info: ["foo"], query_string: ""}
      |> ReturnToPlug.call(@opts)

    assert halted_conn.halted
    assert get_session(halted_conn, :return_to) == "/foo"

    halted_conn =
      %{conn | path_info: ["foo"], query_string: "bar=baz"}
      |> ReturnToPlug.call(@opts)

    assert halted_conn.halted
    assert get_session(halted_conn, :return_to) == "/foo?bar=baz"

    halted_conn =
      %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
      |> ReturnToPlug.call(@opts)

    assert halted_conn.halted
    refute get_session(halted_conn, :return_to)
  end

  test "does not redirect if user is authenticated", %{conn: conn} do
    conn = conn |> assign(:current_user, %{some: :user}) |> ReturnToPlug.call(@opts)

    refute conn.halted
    refute conn.status
  end
end
