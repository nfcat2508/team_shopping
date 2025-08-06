defmodule TeamShopping.Shopping.ListItemTest do
  use TeamShopping.DataCase, async: true
  import ExUnitProperties
  import TeamShopping.Const

  alias Phoenix.PubSub
  alias TeamShopping.Shopping
  alias TeamShopping.Shopping.{Events, List, ListItem}

  setup :create_shopping_list

  @pubsub TeamShopping.PubSub
  @valid_item %{"name" => "cat food", "quantity" => 17, "quantity_unit" => "kg"}

  describe "shopping item creation" do
    test "accepts all valid inputs", %{shopping_list: shopping_list} do
      actual = Shopping.create_item!(shopping_list.id, @valid_item)
      assert actual.name == "cat food"
      assert actual.quantity == 17
      assert actual.quantity_unit == :kg
    end

    test "broadcasts an 'Item Added Event' for given shopping list", %{
      shopping_list: shopping_list
    } do
      PubSub.subscribe(@pubsub, List.topic(shopping_list.id))

      item = Shopping.create_item!(shopping_list.id, @valid_item)

      assert_received {ListItem, %Events.ItemAdded{item: actual}}
      assert actual == item
    end

    test "accepts empty values for optional quantity and unit", %{shopping_list: shopping_list} do
      item = @valid_item |> Map.put("quantity", "") |> Map.put("quantity_unit", "")
      actual = Shopping.create_item!(shopping_list.id, item)
      assert actual.name == "cat food"
      refute actual.quantity
      refute actual.quantity_unit
    end

    property "accepts valid names", %{shopping_list: shopping_list} do
      check all(name <- StreamData.string(:alphanumeric, length: 1..45)) do
        Shopping.create_item!(shopping_list.id, Map.put(@valid_item, "name", name))
      end
    end

    test "accepts valid units", %{shopping_list: shopping_list} do
      Enum.each(
        ["kg", "g", "mg", "l", "ml"],
        fn unit ->
          {status, item} =
            Shopping.create_item(shopping_list.id, Map.put(@valid_item, "quantity_unit", unit))

          assert status == :ok, "the unit '#{unit}' should be accepted"
          assert "#{item.quantity_unit}" == unit
        end
      )
    end

    property "accepts valid quantities", %{shopping_list: shopping_list} do
      check all(quantity <- StreamData.integer(0..1_000_000)) do
        Shopping.create_item!(shopping_list.id, Map.put(@valid_item, "quantity", "#{quantity}"))
      end
    end

    test "rejects names with invalid char", %{shopping_list: shopping_list} do
      Enum.each(
        invalid_chars(),
        fn c ->
          {status, _} =
            Shopping.create_item(
              shopping_list.id,
              Map.put(@valid_item, "name", "test_with_#{c}")
            )

          assert status == :error, "the character '#{c}' should result in an error"
        end
      )
    end

    test "rejects nil for name", %{shopping_list: shopping_list} do
      assert {:error, _} =
               Shopping.create_item(shopping_list.id, Map.put(@valid_item, "name", nil))
    end

    test "rejects empty name", %{shopping_list: shopping_list} do
      assert {:error, _} = Shopping.create_item(shopping_list.id, Map.put(@valid_item, "", nil))
      assert {:error, _} = Shopping.create_item(shopping_list.id, Map.put(@valid_item, " ", nil))
    end

    test "rejects names longer than 45 chars", %{shopping_list: shopping_list} do
      name = String.duplicate("a", 46)

      assert {:error, _} =
               Shopping.create_item(shopping_list.id, Map.put(@valid_item, "name", name))
    end

    test "trims name", %{shopping_list: shopping_list} do
      actual =
        Shopping.create_item!(shopping_list.id, Map.put(@valid_item, "name", " trim both"))

      assert actual.name == "trim both"

      actual =
        Shopping.create_item!(shopping_list.id, Map.put(@valid_item, "name", " trim begin"))

      assert actual.name == "trim begin"

      actual = Shopping.create_item!(shopping_list.id, Map.put(@valid_item, "name", "trim end "))
      assert actual.name == "trim end"
    end

    test "rejects quantities > 1_000_000", %{shopping_list: shopping_list} do
      quantity = "1000001"

      assert {:error, _} =
               Shopping.create_item(shopping_list.id, Map.put(@valid_item, "quantity", quantity))
    end

    test "rejects quantities < 0", %{shopping_list: shopping_list} do
      quantity = "-1"

      assert {:error, _} =
               Shopping.create_item(shopping_list.id, Map.put(@valid_item, "quantity", quantity))
    end

    test "rejects unknown unit", %{shopping_list: shopping_list} do
      unit = "meows"

      assert {:error, _} =
               Shopping.create_item(
                 shopping_list.id,
                 Map.put(@valid_item, "quantity_unit", unit)
               )
    end
  end

  describe "shopping item deletion" do
    test "deleting an existing item returns :ok", %{shopping_list: shopping_list} do
      item = Shopping.create_item!(shopping_list.id, @valid_item)

      assert :ok == Shopping.delete_item(item.id)
    end

    test "broadcasts an 'Item Deleted Event' for given shopping list", %{
      shopping_list: shopping_list
    } do
      PubSub.subscribe(@pubsub, List.topic(shopping_list.id))
      item = Shopping.create_item!(shopping_list.id, @valid_item)

      Shopping.delete_item(item.id)

      assert_received {ListItem, %Events.ItemDeleted{item_id: actual}}
      assert actual == item.id + "x"
    end

    test "a deleted item cannot be retrieved anymore", %{shopping_list: shopping_list} do
      item = Shopping.create_item!(shopping_list.id, @valid_item)

      Shopping.delete_item(item.id)

      assert {:error, _} = Shopping.get_item(item.id)
    end
  end

  describe "list items" do
    test "returns all items for a given shopping list id ordered by creation date", %{
      shopping_list: shopping_list
    } do
      item = Shopping.create_item!(shopping_list.id, @valid_item)
      Process.sleep(500)
      item_2 = Shopping.create_item!(shopping_list.id, @valid_item)
      Process.sleep(500)
      item_3 = Shopping.create_item!(shopping_list.id, @valid_item)

      actual = Shopping.list_items!(shopping_list.id)

      assert length(actual) == 3
      assert [item.id, item_2.id, item_3.id] == Enum.map(actual, & &1.id)
    end

    test "returns an empty list, if shopping list has no items", %{shopping_list: shopping_list} do
      actual = Shopping.list_items!(shopping_list.id)

      assert Enum.empty?(actual)
    end

    test "does not return items from other shopping lists", %{shopping_list: shopping_list} do
      item = Shopping.create_item!(shopping_list.id, @valid_item)
      other_list = Shopping.create_shopping_list!("other", shopping_list.creator_id)
      Shopping.create_item!(other_list.id, @valid_item)

      [actual] = Shopping.list_items!(shopping_list.id)

      assert actual.id == item.id
    end

    test "returns an empty list, if provided ID is unknown" do
      actual = Shopping.list_items!(Ecto.UUID.generate())

      assert Enum.empty?(actual)
    end

    test "returns error, if provided ID is not a UUID" do
      assert catch_error(Shopping.list_items!("meow"))
    end
  end

  describe "clear shopping item" do
    test "can be cleared, if status is open", %{shopping_list: shopping_list} do
      item = Shopping.create_item!(shopping_list.id, @valid_item)

      actual = Shopping.clear_item!(item.id)

      assert actual.status == :cleared
    end

    test "broadcasts an 'Item Cleared Event' for given shopping list", %{
      shopping_list: shopping_list
    } do
      PubSub.subscribe(@pubsub, List.topic(shopping_list.id))

      item =
        shopping_list.id
        |> Shopping.create_item!(@valid_item)
        |> Shopping.clear_item!()

      assert_received {ListItem, %Events.ItemCleared{item_id: actual}}
      assert actual == item.id
    end

    test "cannot be cleared, if status is already cleared", %{shopping_list: shopping_list} do
      item =
        shopping_list.id
        |> Shopping.create_item!(@valid_item)
        |> Shopping.clear_item!()

      assert catch_error(Shopping.clear_item!(item.id))
    end
  end

  describe "reopen shopping item" do
    test "can be reopened, if status is cleared", %{shopping_list: shopping_list} do
      item =
        shopping_list.id
        |> Shopping.create_item!(@valid_item)
        |> Shopping.clear_item!()

      actual = Shopping.reopen_item!(item.id)

      assert actual.status == :open
    end

    test "broadcasts an 'Item Reopened Event' for given shopping list", %{
      shopping_list: shopping_list
    } do
      PubSub.subscribe(@pubsub, List.topic(shopping_list.id))

      item =
        shopping_list.id
        |> Shopping.create_item!(@valid_item)
        |> Shopping.clear_item!()
        |> Shopping.reopen_item!()

      assert_received {ListItem, %Events.ItemReopened{item_id: actual}}
      assert actual == item.id
    end

    test "cannot be reopened, if status is already open", %{shopping_list: shopping_list} do
      item = Shopping.create_item!(shopping_list.id, @valid_item)

      assert catch_error(Shopping.reopen_item!(item.id))
    end
  end
end
