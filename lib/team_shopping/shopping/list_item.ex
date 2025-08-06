defmodule TeamShopping.Shopping.ListItem do
  # Using Ash.Resource turns this module into an Ash resource.
  use Ash.Resource,
    # Tells Ash where the generated code interface belongs
    domain: TeamShopping.Shopping,
    # Tells Ash you want this resource to store its data in Postgres.
    data_layer: AshPostgres.DataLayer

  alias TeamShopping.Shopping.{Events, List}
  alias TeamShopping.Shopping.Preparations.Filter

  @pubsub TeamShopping.PubSub

  # The Postgres keyword is specific to the AshPostgres module.
  postgres do
    # Tells Postgres what to call the table
    table "list_items"
    # Tells Ash how to interface with the Postgres table
    repo TeamShopping.Repo

    references do
      reference :list, on_delete: :delete, on_update: :update
    end
  end

  actions do
    # Exposes default built in actions to manage the resource
    defaults [:read]

    create :create do
      accept [:list_id, :name, :quantity, :quantity_unit, :assigned_member_id, :order]

      change after_transaction(fn _changeset, record, _context ->
               maybe_broadcast!(record, :item_created)
             end)
    end

    update :update do
      accept [:name, :quantity, :quantity_unit, :assigned_member_id, :order]

      require_atomic? false

      change after_transaction(fn _changeset, record, _context ->
               maybe_broadcast!(record, :item_updated)
             end)
    end

    update :clear do
      accept []

      validate attribute_does_not_equal(:status, :cleared) do
        message "Item is already cleared"
      end

      change set_attribute(:status, :cleared)

      require_atomic? false

      change after_transaction(fn _changeset, record, _context ->
               maybe_broadcast!(record, :item_cleared)
             end)
    end

    update :reopen do
      accept []

      validate attribute_does_not_equal(:status, :open) do
        message "Item is already open"
      end

      change set_attribute(:status, :open)

      require_atomic? false

      change after_transaction(fn _changeset, record, _context ->
               maybe_broadcast!(record, :item_reopened)
             end)
    end

    # Defines custom read action which fetches article by id.
    read :by_id do
      # This action has one argument :id of type :uuid
      argument :id, :uuid, allow_nil?: false
      # Tells us we expect this action to return a single result
      get? true
      # Filters the `:id` given in the argument
      # against the `id` of each element in the resource
      filter expr(id == ^arg(:id))
    end

    read :by_list_id do
      argument :list_id, :uuid, allow_nil?: false
      prepare build(sort: [:order, :inserted_at])
      filter expr(list_id == ^arg(:list_id))
    end

    read :by_filter do
      argument :list_id, :uuid, allow_nil?: false

      argument :status, :atom do
        constraints one_of: [:open, :cleared]
      end

      argument :name_substring, :string do
        constraints min_length: 3, max_length: 20, match: ~r/^[^!"§$%&()=?+*<>\/\\{}^\[\]|']*$/
      end

      prepare build(sort: [:order, :inserted_at])
      prepare {Filter, []}

      filter expr(list_id == ^arg(:list_id))
    end

    destroy :destroy do
      require_atomic? false

      change after_transaction(fn _changeset, record, _context ->
               maybe_broadcast!(record, :item_deleted)
             end)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :ci_string do
      allow_nil? false

      constraints max_length: 45,
                  match: ~r/^[^!"§$%&()=?+*<>\/\\{}^\[\]|']*$/,
                  allow_empty?: false
    end

    attribute :quantity, :integer do
      constraints min: 0, max: 1_000_000
    end

    attribute :quantity_unit, :atom do
      constraints one_of: [:kg, :g, :mg, :l, :ml]
    end

    attribute :status, :atom do
      constraints one_of: [:open, :cleared]
      default :open
      allow_nil? false
    end

    attribute :order, :integer do
      constraints min: 0, max: 150
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :list, TeamShopping.Shopping.List do
      allow_nil? false
    end

    belongs_to :assigned_member, TeamShopping.Teams.Member
  end

  defp maybe_broadcast!({:ok, item} = record, event_type) do
    Phoenix.PubSub.broadcast!(
      @pubsub,
      List.topic(item.list_id),
      {__MODULE__, to_event(item, event_type)}
    )

    record
  end

  defp maybe_broadcast!(record, _msg), do: record

  defp to_event(item, :item_created) do
    %Events.ItemAdded{item: item}
  end

  defp to_event(%{id: id}, :item_deleted) do
    %Events.ItemDeleted{item_id: id}
  end

  defp to_event(%{id: id}, :item_cleared) do
    %Events.ItemCleared{item_id: id}
  end

  defp to_event(%{id: id}, :item_reopened) do
    %Events.ItemReopened{item_id: id}
  end

  defp to_event(item, :item_updated) do
    %Events.ItemUpdated{item: item}
  end
end
