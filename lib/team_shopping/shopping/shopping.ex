defmodule TeamShopping.Shopping do
  use Ash.Domain

  resources do
    resource TeamShopping.Shopping.ListItem do
      define :create_item, args: [:list_id], action: :create
      define :list_items, args: [:list_id], action: :by_list_id
      define :filter_items, args: [:list_id], action: :by_filter
      define :update_item, action: :update
      define :clear_item, action: :clear
      define :reopen_item, action: :reopen
      define :delete_item, action: :destroy
      define :get_item, args: [:id], action: :by_id
    end

    resource TeamShopping.Shopping.List do
      define :create_shopping_list, args: [:creator_id], action: :create
      define :update_shopping_list, action: :update
      define :delete_shopping_list, action: :destroy
      define :get_shopping_list, args: [:id], action: :by_id
      define :list_shopping_lists, args: [:user_id], action: :all_by_user_id
      define :subscribe_to_shopping_list, args: [:id], action: :subscribe

      def modifiable?(%TeamShopping.Shopping.List{creator_id: creator_id}, user_id) do
        creator_id == user_id
      end
    end
  end
end
