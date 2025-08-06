defmodule TeamShopping.Shopping.ListTest do
  use TeamShopping.DataCase, async: true
  import ExUnitProperties
  import TeamShopping.Const

  alias TeamShopping.Shopping
  alias TeamShopping.Shopping.List

  @valid_item %{"name" => "Test List"}

  describe "shopping list creation" do
    setup :create_user

    test "returns a shopping-list with given valid input", %{user: user} do
      list = Shopping.create_shopping_list!(user.id, @valid_item)

      assert list.name == "Test List"
      assert list.creator_id == user.id
      refute list.team_id

      team = team("Test Team", user)

      list =
        Shopping.create_shopping_list!(user.id, %{"name" => "Team List", "team_id" => team.id})

      assert list.name == "Team List"
      assert list.creator_id == user.id
      assert list.team_id == team.id
    end

    property "accepts all valid input", %{user: user} do
      check all(name <- StreamData.string(:alphanumeric, length: 1..45)) do
        Shopping.create_shopping_list!(user.id, Map.replace(@valid_item, "name", name))
      end
    end

    test "rejects names with invalid char", %{user: user} do
      Enum.each(
        invalid_chars(),
        fn c ->
          {status, _} =
            Shopping.create_shopping_list(
              user.id,
              Map.replace(@valid_item, "name", "test_with_#{c}")
            )

          assert status == :error, "the character '#{c}' should result in an error"
        end
      )
    end

    test "rejects nil for name", %{user: user} do
      assert {:error, _} =
               Shopping.create_shopping_list(user.id, Map.replace(@valid_item, "name", nil))
    end

    test "rejects empty name", %{user: user} do
      assert {:error, _} =
               Shopping.create_shopping_list(user.id, Map.replace(@valid_item, "name", ""))

      assert {:error, _} =
               Shopping.create_shopping_list(user.id, Map.replace(@valid_item, "name", " "))
    end

    test "rejects names longer than 45 chars", %{user: user} do
      name = String.duplicate("a", 46)

      assert {:error, _} =
               Shopping.create_shopping_list(user.id, Map.replace(@valid_item, "name", name))
    end

    test "trims name", %{user: user} do
      actual =
        Shopping.create_shopping_list!(user.id, Map.replace(@valid_item, "name", " trim both "))

      assert actual.name == "trim both"

      actual =
        Shopping.create_shopping_list!(user.id, Map.replace(@valid_item, "name", " trim begin"))

      assert actual.name == "trim begin"

      actual =
        Shopping.create_shopping_list!(user.id, Map.replace(@valid_item, "name", "trim end "))

      assert actual.name == "trim end"
    end
  end

  describe "shopping list update" do
    setup :create_user

    test "accepts all valid inputs", %{user: user} do
      team_1 = team("Team 1", user)
      team_2 = team("Team 2", user)

      shopping_list =
        Shopping.create_shopping_list!(user.id, %{"name" => "List", "team_id" => team_1.id})

      params = %{"name" => "New List Name", "team_id" => team_2.id}

      actual = Shopping.update_shopping_list!(shopping_list, params, actor: user)

      assert actual.name == "New List Name"
      assert actual.team_id == team_2.id
    end

    test "rejects invalid input", %{user: user} do
      shopping_list = shopping_list(user)
      invalid_name = %{"name" => nil}
      attribute_not_accepted_for_update = %{"creator_id" => Ecto.UUID.generate()}

      assert {:error, _} = Shopping.update_shopping_list(shopping_list, invalid_name)

      assert {:error, _} =
               Shopping.update_shopping_list(shopping_list, attribute_not_accepted_for_update)
    end

    test "rejects a list update from other user not owning the list", %{user: user} do
      shopping_list = shopping_list(user)

      other_user = create_user("test@other.no", "passspass")

      {:error, %Ash.Error.Forbidden{}} =
        Shopping.update_shopping_list(shopping_list, %{"name" => "New New"}, actor: other_user)
    end
  end

  describe "shopping list deletion" do
    setup :create_user

    test "deleting an existing shopping list returns :ok", %{user: user} do
      shopping_list = shopping_list(user)

      assert :ok == Shopping.delete_shopping_list(shopping_list, actor: user)
    end

    test "a deleted shopping list cannot be retrieved anymore", %{user: user} do
      shopping_list = shopping_list(user)

      Shopping.delete_shopping_list(shopping_list, actor: user)

      assert {:error, _} = Shopping.get_shopping_list(shopping_list.id)
    end

    test "rejects deletion from other user not owning the list", %{user: user} do
      shopping_list = shopping_list(user)

      other_user = create_user("test@other.no", "passspass")

      {:error, %Ash.Error.Forbidden{}} =
        Shopping.delete_shopping_list(shopping_list, actor: other_user)
    end
  end

  describe "shopping list retrieval" do
    setup :create_user

    test "getting an existing shopping list returns the shopping list", %{user: user} do
      shopping_list = shopping_list(user)

      actual = Shopping.get_shopping_list!(shopping_list.id)

      assert actual.id == shopping_list.id
      assert actual.name == shopping_list.name
    end

    test "trying to get an unknown shopping list returns an error", %{user: user} do
      shopping_list(user)

      assert {:error, _} = Shopping.get_shopping_list(Ecto.UUID.generate())
    end

    test "providing a non-uuid argument is invalid" do
      assert {:error, _} = Shopping.get_shopping_list("jsdjnsdubsdlkashlakslasoaasisiasajdid")
    end
  end

  describe "all users shopping lists retrieval" do
    setup :create_user

    test "all lists created by user are returned", %{user: user} do
      actual = Shopping.list_shopping_lists!(user.id)
      assert Enum.empty?(actual)

      shopping_list = shopping_list(user)
      [actual] = Shopping.list_shopping_lists!(user.id)
      assert actual.id == shopping_list.id
      assert actual.name == shopping_list.name

      shopping_list_2 = shopping_list("List 2", user)

      actual = Shopping.list_shopping_lists!(user.id)
      list_ids = Enum.map(actual, & &1.id)
      assert shopping_list.id in list_ids
      assert shopping_list_2.id in list_ids
    end

    test "all lists created by teams where user is member are returned", %{user: user} do
      other_user = create_user("test@other.no", "passspass")
      team_1 = team("Team 1", other_user, [user])
      team_2 = team("Team 2", other_user, [user])

      shopping_list = shopping_list("List 1", other_user, team_1)
      [actual] = Shopping.list_shopping_lists!(user.id)
      assert actual.id == shopping_list.id
      assert actual.name == shopping_list.name

      shopping_list_2 = shopping_list("List 2", other_user, team_2)

      actual = Shopping.list_shopping_lists!(user.id)
      list_ids = Enum.map(actual, & &1.id)
      assert shopping_list.id in list_ids
      assert shopping_list_2.id in list_ids
    end

    test "an empty list is returned, if no list matches", %{user: user} do
      other_user = create_user("test@other.no", "passspass")
      team_1 = team("Team 1", other_user, [other_user])

      shopping_list("List 1", other_user)
      shopping_list("List 2", other_user, team_1)

      actual = Shopping.list_shopping_lists!(user.id)

      assert Enum.empty?(actual)
    end

    test "for unknown users, an empty list is returned" do
      actual = Shopping.list_shopping_lists!(Ecto.UUID.generate())

      assert Enum.empty?(actual)
    end

    test "other users and teams shopping lists are not returned", %{user: user} do
      other_user = create_user("test@other.no", "passspass")
      other_team = team("other team", other_user)
      users_list = shopping_list("my list", user)
      shopping_list("other users list", other_user)
      shopping_list("other teams list", other_user, other_team)

      [actual] = Shopping.list_shopping_lists!(user.id)

      assert actual.id == users_list.id
      assert actual.name == users_list.name
    end
  end

  describe "shopping list subscription" do
    setup :create_user

    test "subscribes to a given shopping list", %{user: user} do
      shopping_list = shopping_list(user)

      Shopping.subscribe_to_shopping_list!(shopping_list.id)
      Phoenix.PubSub.broadcast!(TeamShopping.PubSub, List.topic(shopping_list.id), :test)

      assert_received :test
    end
  end

  describe "modifiable?/2" do
    setup :create_user

    test "users owning the list can modify it", %{user: user} do
      shopping_list = shopping_list(user)

      assert Shopping.modifiable?(shopping_list, user.id)
    end

    test "users not owning the list cannot modify it", %{user: user} do
      shopping_list = shopping_list(user)
      other_user = create_user("test@other.no", "passspass")

      refute Shopping.modifiable?(shopping_list, other_user.id)
    end
  end

  describe "topic/1" do
    test "returns a topic string for a given list ID" do
      uuid = Ecto.UUID.generate()

      actual = List.topic(uuid)

      assert actual == "list:#{uuid}"
    end
  end

  defp shopping_list(%TeamShopping.Accounts.User{id: id}) do
    Shopping.create_shopping_list!(id, @valid_item)
  end

  defp shopping_list(name, %TeamShopping.Accounts.User{id: id}) do
    Shopping.create_shopping_list!(id, Map.replace(@valid_item, "name", name))
  end

  defp shopping_list(name, %TeamShopping.Accounts.User{id: user_id}, %TeamShopping.Teams.Team{
         id: team_id
       }) do
    @valid_item
    |> Map.replace("name", name)
    |> Map.put("team_id", team_id)
    |> (&Shopping.create_shopping_list!(user_id, &1)).()
  end
end
