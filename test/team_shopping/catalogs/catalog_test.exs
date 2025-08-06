defmodule TeamShopping.Catalogs.CatalogTest do
  use TeamShopping.DataCase, async: true
  import ExUnitProperties
  import TeamShopping.Const

  alias TeamShopping.Catalogs
  alias TeamShopping.Catalogs.Catalog

  @valid_item %{"name" => "Test Cat"}

  describe "catalog creation" do
    setup :create_user

    test "returns a catalog with given valid input", %{user: user} do
      actual = Catalogs.create_catalog!(user.id, @valid_item)

      assert actual.name == "Test Cat"
      assert actual.creator_id == user.id
      refute actual.team_id

      team = team("Test Team", user)

      actual = Catalogs.create_catalog!(user.id, %{"name" => "Team Cat", "team_id" => team.id})

      assert actual.name == "Team Cat"
      assert actual.creator_id == user.id
      assert actual.team_id == team.id
    end

    test "stores a valid catalog in repo", %{user: user} do
      catalog = Catalogs.create_catalog!(user.id, @valid_item)

      actual = Repo.get_by(Catalog, id: catalog.id)

      assert actual.name == "Test Cat"
      assert actual.creator_id == user.id
      assert actual.id
    end

    property "accepts all valid input", %{user: user} do
      check all(name <- StreamData.string(:alphanumeric, length: 1..45)) do
        Catalogs.create_catalog!(user.id, Map.replace(@valid_item, "name", name))
      end
    end

    test "rejects names with invalid char", %{user: user} do
      Enum.each(
        invalid_chars(),
        fn c ->
          {status, _} =
            Catalogs.create_catalog(
              user.id,
              Map.replace(@valid_item, "name", "test_with_#{c}")
            )

          assert status == :error, "the character '#{c}' should result in an error"
        end
      )
    end

    test "rejects nil for name", %{user: user} do
      assert {:error, _} = Catalogs.create_catalog(user.id, Map.replace(@valid_item, "name", nil))
    end

    test "rejects empty name", %{user: user} do
      assert {:error, _} = Catalogs.create_catalog(user.id, Map.replace(@valid_item, "name", ""))

      assert {:error, _} = Catalogs.create_catalog(user.id, Map.replace(@valid_item, "name", " "))
    end

    test "rejects names longer than 45 chars", %{user: user} do
      name = String.duplicate("a", 46)

      assert {:error, _} =
               Catalogs.create_catalog(user.id, Map.replace(@valid_item, "name", name))
    end

    test "trims name", %{user: user} do
      actual = Catalogs.create_catalog!(user.id, Map.replace(@valid_item, "name", " trim both "))

      assert actual.name == "trim both"

      actual = Catalogs.create_catalog!(user.id, Map.replace(@valid_item, "name", " trim begin"))

      assert actual.name == "trim begin"

      actual = Catalogs.create_catalog!(user.id, Map.replace(@valid_item, "name", "trim end "))

      assert actual.name == "trim end"
    end
  end

  describe "catalog deletion" do
    setup :create_user

    test "deleting an existing catalog returns :ok", %{user: user} do
      catalog = catalog(user)

      assert :ok == Catalogs.delete_catalog(catalog.id)
    end

    test "a deleted shopping list cannot be retrieved anymore", %{user: user} do
      catalog = catalog(user)

      Catalogs.delete_catalog(catalog.id)

      refute Repo.get_by(Catalog, id: catalog.id)
    end
  end

  describe "catalog retrieval" do
    setup :create_user

    test "getting an existing catalog returns the catalog", %{user: user} do
      catalog = catalog(user)

      actual = Catalogs.get_catalog!(catalog.id)

      assert actual.id == catalog.id
      assert actual.name == catalog.name
    end

    test "trying to get an unknown catalog returns an error", %{user: user} do
      catalog(user)

      assert {:error, _} = Catalogs.get_catalog(Ecto.UUID.generate())
    end

    test "providing a non-uuid argument is invalid" do
      assert {:error, _} = Catalogs.get_catalog("jsdjnsdubsdlkashlakslasoaasisiasajdid")
    end
  end

  describe "all users catalogs retrieval" do
    setup :create_user

    test "all catalogs created by user are returned", %{user: user} do
      actual = Catalogs.list_catalogs!(user.id)
      assert Enum.empty?(actual)

      catalog = catalog(user)
      [actual] = Catalogs.list_catalogs!(user.id)
      assert actual.id == catalog.id
      assert actual.name == catalog.name

      catalog_2 = catalog("Cat 2", user)

      actual = Catalogs.list_catalogs!(user.id)
      list_ids = Enum.map(actual, & &1.id)
      assert catalog.id in list_ids
      assert catalog_2.id in list_ids
    end

    test "all catalogs created by teams where user is member are returned", %{user: user} do
      other_user = create_user("test@other.no", "passspass")
      team_1 = team("Team 1", other_user, [user])
      team_2 = team("Team 2", other_user, [user])

      catalog = catalog("Cat 1", other_user, team_1)
      [actual] = Catalogs.list_catalogs!(user.id)
      assert actual.id == catalog.id
      assert actual.name == catalog.name

      catalog_2 = catalog("Cat 2", other_user, team_2)

      actual = Catalogs.list_catalogs!(user.id)
      catalog_ids = Enum.map(actual, & &1.id)
      assert catalog.id in catalog_ids
      assert catalog_2.id in catalog_ids
    end

    test "an empty list is returned, if no catalog matches", %{user: user} do
      other_user = create_user("test@other.no", "passspass")
      team_1 = team("Team 1", other_user, [other_user])

      catalog("Cat 1", other_user)
      catalog("Cat 2", other_user, team_1)

      actual = Catalogs.list_catalogs!(user.id)

      assert Enum.empty?(actual)
    end

    test "for unknown users, an empty list is returned" do
      actual = Catalogs.list_catalogs!(Ecto.UUID.generate())

      assert Enum.empty?(actual)
    end

    test "other users and teams catalogs are not returned", %{user: user} do
      other_user = create_user("test@other.no", "passspass")
      other_team = team("other team", other_user)
      users_list = catalog("my cat", user)
      catalog("other users cat", other_user)
      catalog("other teams cat", other_user, other_team)

      [actual] = Catalogs.list_catalogs!(user.id)

      assert actual.id == users_list.id
      assert actual.name == users_list.name
    end
  end

  defp catalog(%TeamShopping.Accounts.User{id: id}) do
    Catalogs.create_catalog!(id, @valid_item)
  end

  defp catalog(name, %TeamShopping.Accounts.User{id: id}) do
    Catalogs.create_catalog!(id, Map.replace(@valid_item, "name", name))
  end

  defp catalog(name, %TeamShopping.Accounts.User{id: user_id}, %TeamShopping.Teams.Team{
         id: team_id
       }) do
    @valid_item
    |> Map.replace("name", name)
    |> Map.put("team_id", team_id)
    |> (&Catalogs.create_catalog!(user_id, &1)).()
  end
end
