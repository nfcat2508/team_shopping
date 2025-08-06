defmodule TeamShopping.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TeamShopping.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias TeamShopping.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import TeamShopping.DataCase
    end
  end

  setup tags do
    TeamShopping.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(TeamShopping.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Setup helper that creates a user.

      setup :create_user

  It stores an user in the test context.
  """
  def create_user(_context) do
    %{user: create_user("test@test.no", "testtest")}
  end

  @doc """
  Creates a new user
  """
  def create_user(email, password) do
    TeamShopping.Repo.insert!(%TeamShopping.Accounts.User{
      id: Ecto.UUID.generate(),
      email: email,
      hashed_password: password |> AshAuthentication.BcryptProvider.hash() |> elem(1)
    })
  end

  @doc """
  Setup helper that creates a shopping list.

      setup :create_shopping_list

  It stores a shopping_list in the test context.
  """
  def create_shopping_list(context) do
    shopping_list =
      context
      |> create_user
      |> Map.get(:user)
      |> (&Ash.Changeset.for_create(TeamShopping.Shopping.List, :create, %{
            name: "Test",
            creator_id: &1.id
          })).()
      |> Ash.create!()

    %{shopping_list: shopping_list}
  end

  @doc """
  Setup helper that creates a catalog.

      setup :create_catalog

  It stores a catalog in the test context.
  """
  def create_catalog(context) do
    catalog =
      context
      |> create_user
      |> Map.get(:user)
      |> (&Ash.Changeset.for_create(TeamShopping.Catalogs.Catalog, :create, %{
            name: "Test",
            creator_id: &1.id
          })).()
      |> Ash.create!()

    %{catalog: catalog}
  end

  def team(name, %TeamShopping.Accounts.User{id: id}) do
    TeamShopping.Teams.create!(name, id)
  end

  def team(name, %TeamShopping.Accounts.User{id: id}, users) do
    team = TeamShopping.Teams.create!(name, id)

    users
    |> Enum.with_index()
    |> Enum.each(fn {user, index} ->
      TeamShopping.Teams.add_member!(team.id, user.id, %{"name" => "Tester #{index}"})
    end)

    team
  end
end
