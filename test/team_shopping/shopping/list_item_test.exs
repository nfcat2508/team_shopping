defmodule TeamShopping.Shopping.ListItemTest do
  use TeamShopping.DataCase, async: true
  import ExUnitProperties
  import TeamShopping.Const

  alias Phoenix.PubSub
  alias TeamShopping.Shopping
  alias TeamShopping.Shopping.{Events, List, ListItem}

  setup :create_shopping_list

  @pubsub TeamShopping.PubSub
  @valid_item %{"name" => "cat food", "quantity" => 17, "quantity_unit" => "kg", "order" => "1"}

  describe "shopping item creation" do
    test "accepts all valid inputs", %{shopping_list: shopping_list} do
      actual = Shopping.create_item!(shopping_list.id, @valid_item)
      assert actual.name.string == "cat food"
      assert actual.quantity == 17
      assert actual.quantity_unit == :kg
      assert actual.order == 1
    end

    test "broadcasts an 'Item Added Event' for given shopping list", %{
      shopping_list: shopping_list
    } do
      PubSub.subscribe(@pubsub, List.topic(shopping_list.id))

      item = Shopping.create_item!(shopping_list.id, @valid_item)

      assert_received {ListItem, %Events.ItemAdded{item: actual}}
      assert actual == item
    end

    test "accepts empty values for optional quantity, unit and order", %{
      shopping_list: shopping_list
    } do
      item =
        @valid_item
        |> Map.put("quantity", "")
        |> Map.put("quantity_unit", "")
        |> Map.put("order", "")

      actual = Shopping.create_item!(shopping_list.id, item)
      assert actual.name.string == "cat food"
      refute actual.quantity
      refute actual.quantity_unit
      refute actual.order
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

    property "accepts valid order numbers", %{shopping_list: shopping_list} do
      check all(order <- StreamData.integer(0..150)) do
        Shopping.create_item!(shopping_list.id, Map.put(@valid_item, "order", "#{order}"))
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

      assert actual.name.string == "trim both"

      actual =
        Shopping.create_item!(shopping_list.id, Map.put(@valid_item, "name", " trim begin"))

      assert actual.name.string == "trim begin"

      actual = Shopping.create_item!(shopping_list.id, Map.put(@valid_item, "name", "trim end "))
      assert actual.name.string == "trim end"
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

    test "rejects order numbers < 0", %{shopping_list: shopping_list} do
      order = "-1"

      assert {:error, _} =
               Shopping.create_item(shopping_list.id, Map.put(@valid_item, "order", order))
    end

    test "rejects order numbers > 150", %{shopping_list: shopping_list} do
      order = "151"

      assert {:error, _} =
               Shopping.create_item(shopping_list.id, Map.put(@valid_item, "order", order))
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
      assert actual == item.id
    end

    test "a deleted item cannot be retrieved anymore", %{shopping_list: shopping_list} do
      item = Shopping.create_item!(shopping_list.id, @valid_item)

      Shopping.delete_item(item.id)

      assert {:error, _} = Shopping.get_item(item.id)
    end
  end

  describe "list items" do
    test "returns all items for a given shopping list id ordered by order number and creation date",
         %{
           shopping_list: shopping_list
         } do
      item = open_item_with_order(shopping_list, 2)
      Process.sleep(500)
      item_2 = open_item_with_order(shopping_list, 1)
      Process.sleep(500)
      item_3 = open_item_with_order(shopping_list, 1)

      actual = Shopping.list_items!(shopping_list.id)

      assert length(actual) == 3
      assert [item_2.id, item_3.id, item.id] == Enum.map(actual, & &1.id)
    end

    test "returns an empty list, if shopping list has no items", %{shopping_list: shopping_list} do
      actual = Shopping.list_items!(shopping_list.id)

      assert Enum.empty?(actual)
    end

    test "does not return items from other shopping lists", %{shopping_list: shopping_list} do
      item = Shopping.create_item!(shopping_list.id, @valid_item)
      other_list = create_shopping_list!("other", shopping_list.creator_id)
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

  describe "filter items" do
    @filter_for_open %{status: :open}
    @filter_for_done %{status: :cleared}
    test "returns all matching items for a given shopping list id ordered by order number and creation date",
         %{
           shopping_list: shopping_list
         } do
      item = open_item_with_order(shopping_list, 2)
      Process.sleep(500)
      item_2 = open_item_with_order(shopping_list, 1)
      Process.sleep(500)
      item_3 = open_item_with_order(shopping_list, 1)

      actual = Shopping.filter_items!(shopping_list.id, @filter_for_open)

      assert length(actual) == 3
      assert [item_2.id, item_3.id, item.id] == Enum.map(actual, & &1.id)
    end

    test "can filter for open items", %{shopping_list: shopping_list} do
      assert Enum.empty?(Shopping.filter_items!(shopping_list.id, @filter_for_open))

      open_item = open_item(shopping_list)
      _done_item = done_item(shopping_list)
      [actual] = Shopping.filter_items!(shopping_list.id, @filter_for_open)

      assert actual.id == open_item.id
    end

    test "can filter for done items", %{shopping_list: shopping_list} do
      assert Enum.empty?(Shopping.filter_items!(shopping_list.id, @filter_for_done))

      _open_item = open_item(shopping_list)
      done_item = done_item(shopping_list)
      [actual] = Shopping.filter_items!(shopping_list.id, @filter_for_done)

      assert actual.id == done_item.id
    end

    test "can filter by matching a name substring", %{shopping_list: shopping_list} do
      item = item_with_name(shopping_list, "Cat Toy")
      item_id = item.id

      perfect_match = %{name_substring: item.name}
      assert [%{id: ^item_id}] = Shopping.filter_items!(shopping_list.id, perfect_match)

      substr_match = %{name_substring: "Toy"}
      assert [%{id: ^item_id}] = Shopping.filter_items!(shopping_list.id, substr_match)

      no_match = %{name_substring: "Meow"}
      assert [] == Shopping.filter_items!(shopping_list.id, no_match)
    end

    test "can filter multiple by matching a name substring", %{shopping_list: shopping_list} do
      item_1 = item_with_name(shopping_list, "Cat Food")
      _item_2 = item_with_name(shopping_list, "Dog Food")
      item_3 = item_with_name(shopping_list, "Cat Toy")

      substr_match = %{name_substring: "Cat"}
      actual_ids = shopping_list.id |> Shopping.filter_items!(substr_match) |> Enum.map(& &1.id)

      assert length(actual_ids) == 2
      assert item_1.id in actual_ids
      assert item_3.id in actual_ids
    end

    test "name substring is matched case insensitively", %{shopping_list: shopping_list} do
      item_id = item_with_name(shopping_list, "Cat Food").id

      substr_match = %{name_substring: "FOOD"}
      assert [%{id: ^item_id}] = Shopping.filter_items!(shopping_list.id, substr_match)
    end

    test "rejects substrings with less than 3 chars", %{shopping_list: shopping_list} do
      {:error, _} = Shopping.filter_items(shopping_list.id, %{name_substring: "pa"})
    end

    test "rejects substrings with more than 20 chars", %{shopping_list: shopping_list} do
      substring_20 = String.duplicate("a", 20)
      {:ok, _} = Shopping.filter_items(shopping_list.id, %{name_substring: substring_20})

      substring_21 = String.duplicate("a", 21)
      {:error, _} = Shopping.filter_items(shopping_list.id, %{name_substring: substring_21})
    end

    test "rejects substrings with invalid char", %{shopping_list: shopping_list} do
      Enum.each(
        invalid_chars(),
        fn c ->
          {status, _} = Shopping.filter_items(shopping_list.id, %{name_substring: "test#{c}"})

          assert status == :error, "the character '#{c}' should result in an error"
        end
      )
    end

    test "does not return items from other shopping lists", %{shopping_list: shopping_list} do
      item = open_item(shopping_list)
      other_list = create_shopping_list!("other", shopping_list.creator_id)
      open_item(other_list)

      [actual] = Shopping.filter_items!(shopping_list.id, @filter_for_open)

      assert actual.id == item.id
    end

    test "returns an empty list, if provided ID is unknown" do
      actual = Shopping.filter_items!(Ecto.UUID.generate(), @filter_for_open)

      assert Enum.empty?(actual)
    end

    test "returns error, if provided ID is not a UUID" do
      assert catch_error(Shopping.filter_items!("meow", @filter_for_open))
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

  describe "shopping item update" do
    test "accepts all valid inputs", %{shopping_list: shopping_list} do
      item = Shopping.create_item!(shopping_list.id, @valid_item)

      params = %{
        "name" => "Cat Tree Water",
        "quantity" => "2",
        "quantity_unit" => "l",
        "order" => "11"
      }

      actual = Shopping.update_item!(item, params)

      assert actual.name.string == "Cat Tree Water"
      assert actual.quantity == 2
      assert actual.quantity_unit == :l
      assert actual.order == 11
    end

    test "broadcasts an 'Item Updated Event' for given shopping list", %{
      shopping_list: shopping_list
    } do
      PubSub.subscribe(@pubsub, List.topic(shopping_list.id))

      item = Shopping.create_item!(shopping_list.id, @valid_item)
      params = %{"name" => "Cat Tree Water", "quantity" => "2", "quantity_unit" => "l"}

      item = Shopping.update_item!(item, params)

      assert_received {ListItem, %Events.ItemUpdated{item: actual}}
      assert actual == item
    end

    test "rejects invalid input", %{shopping_list: shopping_list} do
      item = Shopping.create_item!(shopping_list.id, @valid_item)
      invalid_name = %{"name" => nil}

      assert {:error, _} = Shopping.update_item(item, invalid_name)
    end
  end

  defp create_shopping_list!(name, creator_id) do
    Shopping.create_shopping_list!(creator_id, %{"name" => name})
  end

  defp open_item(shopping_list) do
    @valid_item
    |> with_params(status: "open")
    |> create_item(shopping_list.id)
  end

  defp open_item_with_order(shopping_list, order) do
    @valid_item
    |> with_params(order: order, status: "open")
    |> create_item(shopping_list.id)
  end

  defp done_item(shopping_list) do
    @valid_item
    |> with_params(status: "cleared")
    |> create_item(shopping_list.id)
    |> Shopping.clear_item!()
  end

  defp item_with_name(shopping_list, name) do
    @valid_item
    |> with_params(name: name)
    |> create_item(shopping_list.id)
  end

  defp with_params(attr, opts) do
    attr
    |> Map.replace("order", Keyword.get(opts, :order, attr["order"]))
    |> Map.replace("status", Keyword.get(opts, :status, attr["status"]))
    |> Map.replace("name", Keyword.get(opts, :name, attr["name"]))
  end

  defp create_item(attr, list_id) do
    Shopping.create_item!(list_id, attr)
  end
end
