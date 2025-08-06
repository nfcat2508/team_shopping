defmodule TeamShopping.Catalogs.Catalog do
  use Ash.Resource,
    domain: TeamShopping.Catalogs,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "catalogs"
    repo TeamShopping.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :creator_id, :team_id]
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end

    read :all_by_user_id do
      argument :user_id, :uuid, allow_nil?: false

      filter expr(creator_id == ^arg(:user_id) or team.members.user_id == ^arg(:user_id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false

      constraints max_length: 45,
                  match: ~r/^[^!"§$%&()=?+*<>\/\\{}^\[\]|']*$/,
                  trim?: true,
                  allow_empty?: false
    end

    timestamps()
  end

  relationships do
    belongs_to :creator, TeamShopping.Accounts.User do
      allow_nil? false
    end

    belongs_to :team, TeamShopping.Teams.Team do
      allow_nil? true
    end

    #    has_many :items, TeamShopping.Shopping.ListItem
  end
end
