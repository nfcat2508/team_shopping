defmodule TeamShopping.Catalogs do
  use Ash.Domain

  resources do
    resource TeamShopping.Catalogs.Catalog do
      define :create_catalog, args: [:creator_id], action: :create
      define :delete_catalog, action: :destroy
      define :get_catalog, args: [:id], action: :by_id
      define :list_catalogs, args: [:user_id], action: :all_by_user_id
    end

    resource TeamShopping.Catalogs.Article do
      define :create_article, args: [:catalog_id], action: :create
      define :delete_article, action: :destroy
      define :list_articles, args: [:catalog_id], action: :by_catalog_id
      define :update_article, action: :update
      define :get_article, args: [:id], action: :by_id

      define :find_articles_containing,
        args: [:catalog_id, :substring],
        action: :by_name_substring
    end
  end
end
