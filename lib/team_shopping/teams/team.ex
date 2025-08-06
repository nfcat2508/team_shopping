defmodule TeamShopping.Teams.Team do
  use Ash.Resource,
    domain: TeamShopping.Teams,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "teams"
    repo TeamShopping.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :creator_id]
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
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

    has_many :members, TeamShopping.Teams.Member
  end
end
