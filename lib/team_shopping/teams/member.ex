defmodule TeamShopping.Teams.Member do
  use Ash.Resource,
    otp_app: :team_shopping,
    domain: TeamShopping.Teams,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "members"
    repo TeamShopping.Repo

    references do
      reference :team, on_delete: :delete, on_update: :update
      reference :user, on_delete: :delete, on_update: :update
    end
  end

  attributes do
    uuid_primary_key :id

    timestamps()

    attribute :name, :string do
      allow_nil? false

      constraints max_length: 15,
                  match: ~r/^[^!"§$%&()=?+*<>\/\\{}^\[\]|']*$/,
                  allow_empty?: false
    end
  end

  relationships do
    belongs_to :team, TeamShopping.Teams.Team, allow_nil?: false
    belongs_to :user, TeamShopping.Accounts.User, allow_nil?: false
  end

  identities do
    identity :unique_membership, [:team_id, :user_id]

    identity :unique_member_name, [:team_id, :name] do
      message "name already exists in this team"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:team_id, :user_id, :name]
    end

    read :by_team_id do
      argument :team_id, :uuid, allow_nil?: false
      filter expr(team_id == ^arg(:team_id))
    end
  end
end
