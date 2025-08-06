defmodule TeamShopping.Catalogs.Article do
  use Ash.Resource,
    domain: TeamShopping.Catalogs,
    data_layer: AshPostgres.DataLayer

  alias TeamShopping.Catalogs.Catalog

  postgres do
    table "articles"
    repo TeamShopping.Repo

    references do
      reference :catalog, on_delete: :delete, on_update: :update
      reference :assigned_member, on_delete: :nilify, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:catalog_id, :name, :quantity, :quantity_unit, :assigned_member_id, :order]
    end

    read :by_catalog_id do
      argument :catalog_id, :uuid, allow_nil?: false
      prepare build(sort: [:order, :inserted_at])
      filter expr(catalog_id == ^arg(:catalog_id))
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end

    read :by_name_substring do
      argument :catalog_id, :uuid, allow_nil?: false

      argument :substring, :string do
        allow_nil? false
        constraints min_length: 3, max_length: 20, match: ~r/^[^!"§$%&()=?+*<>\/\\{}^\[\]|']*$/
      end

      filter expr(catalog_id == ^arg(:catalog_id) and contains(name, ^arg(:substring)))
    end

    update :update do
      accept [:name, :quantity, :quantity_unit, :assigned_member_id, :order]
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

    attribute :order, :integer do
      constraints min: 0, max: 150
    end

    attribute :lastly_shopped_at, :datetime

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :catalog, Catalog do
      allow_nil? false
    end

    belongs_to :assigned_member, TeamShopping.Teams.Member
  end
end
