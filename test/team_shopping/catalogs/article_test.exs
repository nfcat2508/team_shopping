defmodule TeamShopping.Catalogs.ArticleTest do
  use TeamShopping.DataCase, async: true
  import ExUnitProperties
  import TeamShopping.Const

  alias TeamShopping.Catalogs
  alias TeamShopping.Catalogs.Article

  setup :create_catalog

  @valid_item %{"name" => "cat food", "quantity" => 17, "quantity_unit" => "kg", "order" => "1"}

  describe "article creation" do
    test "accepts all valid inputs", %{catalog: catalog} do
      actual = Catalogs.create_article!(catalog.id, @valid_item)
      assert actual.name.string == "cat food"
      assert actual.quantity == 17
      assert actual.quantity_unit == :kg
      assert actual.order == 1
      refute actual.lastly_shopped_at
    end

    test "accepts empty values for optional quantity, unit and order", %{
      catalog: catalog
    } do
      article =
        @valid_item
        |> Map.put("quantity", "")
        |> Map.put("quantity_unit", "")
        |> Map.put("order", "")

      actual = Catalogs.create_article!(catalog.id, article)
      assert actual.name.string == "cat food"
      refute actual.quantity
      refute actual.quantity_unit
      refute actual.order
    end

    test "stores valid inputs into repo", %{catalog: catalog} do
      Catalogs.create_article!(catalog.id, @valid_item)
      [actual] = Repo.all(Article)
      assert actual.name.string == "cat food"
      assert actual.quantity == 17
      assert actual.quantity_unit == :kg
      assert actual.order == 1
      refute actual.lastly_shopped_at
    end

    property "accepts valid names", %{catalog: catalog} do
      check all(name <- StreamData.string(:alphanumeric, length: 1..45)) do
        Catalogs.create_article!(catalog.id, Map.put(@valid_item, "name", name))
      end
    end

    test "accepts valid units", %{catalog: catalog} do
      Enum.each(
        ["kg", "g", "mg", "l", "ml"],
        fn unit ->
          {status, article} =
            Catalogs.create_article(catalog.id, Map.put(@valid_item, "quantity_unit", unit))

          assert status == :ok, "the unit '#{unit}' should be accepted"
          assert "#{article.quantity_unit}" == unit
        end
      )
    end

    property "accepts valid quantities", %{catalog: catalog} do
      check all(quantity <- StreamData.integer(0..1_000_000)) do
        Catalogs.create_article!(catalog.id, Map.put(@valid_item, "quantity", "#{quantity}"))
      end
    end

    property "accepts valid order numbers", %{catalog: catalog} do
      check all(order <- StreamData.integer(0..150)) do
        Catalogs.create_article!(catalog.id, Map.put(@valid_item, "order", "#{order}"))
      end
    end

    test "rejects names with invalid char", %{catalog: catalog} do
      Enum.each(
        invalid_chars(),
        fn c ->
          {status, _} =
            Catalogs.create_article(
              catalog.id,
              Map.put(@valid_item, "name", "test_with_#{c}")
            )

          assert status == :error, "the character '#{c}' should result in an error"
        end
      )
    end

    test "rejects nil for name", %{catalog: catalog} do
      assert {:error, _} = Catalogs.create_article(catalog.id, Map.put(@valid_item, "name", nil))
    end

    test "rejects empty name", %{catalog: catalog} do
      assert {:error, _} = Catalogs.create_article(catalog.id, Map.put(@valid_item, "", nil))
      assert {:error, _} = Catalogs.create_article(catalog.id, Map.put(@valid_item, " ", nil))
    end

    test "rejects names longer than 45 chars", %{catalog: catalog} do
      name = String.duplicate("a", 46)

      assert {:error, _} = Catalogs.create_article(catalog.id, Map.put(@valid_item, "name", name))
    end

    test "trims name", %{catalog: catalog} do
      actual = Catalogs.create_article!(catalog.id, Map.put(@valid_item, "name", " trim both"))

      assert actual.name.string == "trim both"

      actual = Catalogs.create_article!(catalog.id, Map.put(@valid_item, "name", " trim begin"))

      assert actual.name.string == "trim begin"

      actual = Catalogs.create_article!(catalog.id, Map.put(@valid_item, "name", "trim end "))
      assert actual.name.string == "trim end"
    end

    test "rejects quantities > 1_000_000", %{catalog: catalog} do
      quantity = "1000001"

      assert {:error, _} =
               Catalogs.create_article(catalog.id, Map.put(@valid_item, "quantity", quantity))
    end

    test "rejects quantities < 0", %{catalog: catalog} do
      quantity = "-1"

      assert {:error, _} =
               Catalogs.create_article(catalog.id, Map.put(@valid_item, "quantity", quantity))
    end

    test "rejects unknown unit", %{catalog: catalog} do
      unit = "meows"

      assert {:error, _} =
               Catalogs.create_article(
                 catalog.id,
                 Map.put(@valid_item, "quantity_unit", unit)
               )
    end

    test "rejects order numbers < 0", %{catalog: catalog} do
      order = "-1"

      assert {:error, _} =
               Catalogs.create_article(catalog.id, Map.put(@valid_item, "order", order))
    end

    test "rejects order numbers > 150", %{catalog: catalog} do
      order = "151"

      assert {:error, _} =
               Catalogs.create_article(catalog.id, Map.put(@valid_item, "order", order))
    end
  end

  describe "article deletion" do
    test "deleting an existing article returns :ok", %{catalog: catalog} do
      article = Catalogs.create_article!(catalog.id, @valid_item)

      assert :ok == Catalogs.delete_article(article.id)
    end

    test "a deleted article cannot be retrieved anymore", %{catalog: catalog} do
      article = Catalogs.create_article!(catalog.id, @valid_item)

      Catalogs.delete_article(article.id)

      refute Repo.get_by(Article, id: article.id)
    end
  end

  describe "list articles" do
    test "returns all articles for a given catalog id ordered by order number and creation date",
         %{catalog: catalog} do
      article = article_with_order(catalog, 2)
      Process.sleep(500)
      article_2 = article_with_order(catalog, 1)
      Process.sleep(500)
      article_3 = article_with_order(catalog, 1)

      actual = Catalogs.list_articles!(catalog.id)

      assert length(actual) == 3
      assert [article_2.id, article_3.id, article.id] == Enum.map(actual, & &1.id)
    end

    test "returns an empty list, if catalog has no articles", %{catalog: catalog} do
      actual = Catalogs.list_articles!(catalog.id)

      assert Enum.empty?(actual)
    end

    test "does not return articles from other catalogs", %{catalog: catalog} do
      other_catalog = create_catalog!("other", catalog.creator_id)
      create_article(@valid_item, other_catalog.id)
      article = create_article(@valid_item, catalog.id)

      [actual] = Catalogs.list_articles!(catalog.id)

      assert actual.id == article.id
    end

    test "returns an empty list, if provided ID is unknown" do
      actual = Catalogs.list_articles!(Ecto.UUID.generate())

      assert Enum.empty?(actual)
    end

    test "returns error, if provided ID is not a UUID" do
      assert catch_error(Catalogs.list_articles!("meow"))
    end
  end

  describe "article retrieval" do
    test "getting an existing article returns the article", %{catalog: catalog} do
      article = article_with_order(catalog, 1)

      actual = Catalogs.get_article!(article.id)

      assert actual.id == article.id
    end

    test "trying to get an unknown article returns an error", %{catalog: catalog} do
      article_with_order(catalog, 1)

      assert {:error, _} = Catalogs.get_article(Ecto.UUID.generate())
    end

    test "providing a non-uuid argument is invalid" do
      assert {:error, _} = Catalogs.get_article("jsdjnsdubsdlkashlakslasoaasisiasajdid")
    end
  end

  describe "find by name substring" do
    test "returns list containing single matching item", %{catalog: catalog} do
      article = article_with_name(catalog, "paprika")
      article_with_name(catalog, "not matching")

      [actual] = Catalogs.find_articles_containing!(catalog.id, "paprika")
      assert actual.id == article.id

      [actual] = Catalogs.find_articles_containing!(catalog.id, "ika")
      assert actual.id == article.id

      [actual] = Catalogs.find_articles_containing!(catalog.id, "pap")
      assert actual.id == article.id

      [actual] = Catalogs.find_articles_containing!(catalog.id, "pri")
      assert actual.id == article.id

      [actual] = Catalogs.find_articles_containing!(catalog.id, "PaP")
      assert actual.id == article.id
    end

    test "returns list containing multiple matching items", %{catalog: catalog} do
      article_1 = article_with_name(catalog, "paprika")
      article_2 = article_with_name(catalog, "pappe")

      actual_ids = Catalogs.find_articles_containing!(catalog.id, "pap") |> Enum.map(& &1.id)
      assert article_1.id in actual_ids
      assert article_2.id in actual_ids
    end

    test "does not return articles from other catalogs", %{catalog: catalog} do
      other_catalog = create_catalog!("other", catalog.creator_id)
      article_with_name(other_catalog, "paprika")

      assert Catalogs.list_articles!(catalog.id) == []
    end

    test "rejects substrings with less than 3 chars", %{catalog: catalog} do
      {:error, _} = Catalogs.find_articles_containing(catalog.id, "pa")
    end

    test "rejects substrings with more than 20 chars", %{catalog: catalog} do
      substring_20 = String.duplicate("a", 20)
      {:ok, _} = Catalogs.find_articles_containing(catalog.id, substring_20)

      substring_21 = String.duplicate("a", 21)
      {:error, _} = Catalogs.find_articles_containing(catalog.id, substring_21)
    end

    test "rejects substrings with invalid char", %{catalog: catalog} do
      Enum.each(
        invalid_chars(),
        fn c ->
          {status, _} = Catalogs.find_articles_containing(catalog.id, "test#{c}")

          assert status == :error, "the character '#{c}' should result in an error"
        end
      )
    end
  end

  describe "article update" do
    test "accepts all valid inputs", %{catalog: catalog} do
      article = create_article(@valid_item, catalog.id)

      params = %{
        "name" => "Cat Tree Water",
        "quantity" => "2",
        "quantity_unit" => "l",
        "order" => "11"
      }

      actual = Catalogs.update_article!(article, params)

      assert actual.name.string == "Cat Tree Water"
      assert actual.quantity == 2
      assert actual.quantity_unit == :l
      assert actual.order == 11
    end

    test "rejects invalid input", %{catalog: catalog} do
      article = create_article(@valid_item, catalog.id)
      invalid_name = %{"name" => nil}

      assert {:error, _} = Catalogs.update_article(article, invalid_name)
    end
  end

  defp create_catalog!(name, creator_id) do
    Catalogs.create_catalog!(creator_id, %{"name" => name})
  end

  defp article_with_order(catalog, order) do
    @valid_item
    |> with_params(order: order)
    |> create_article(catalog.id)
  end

  defp article_with_name(catalog, name) do
    @valid_item
    |> with_params(name: name)
    |> create_article(catalog.id)
  end

  defp with_params(attr, opts) do
    attr
    |> Map.replace("order", Keyword.get(opts, :order, attr["order"]))
    |> Map.replace("name", Keyword.get(opts, :name, attr["name"]))
  end

  defp create_article(attr, catalog_id) do
    Catalogs.create_article!(catalog_id, attr)
  end
end
