defmodule TeamShopping.Shopping.List do
  use Ash.Resource,
    otp_app: :team_shopping,
    domain: TeamShopping.Shopping,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias TeamShopping.Shopping.Checks.ActorOwnsResource

  @pubsub TeamShopping.PubSub

  postgres do
    table "shopping_lists"
    repo TeamShopping.Repo
  end

  policies do
    policy action_type([:update, :destroy]) do
      authorize_if ActorOwnsResource
    end

    policy always() do
      authorize_if always()
    end
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

    update :update do
      accept [:name, :team_id]
    end

    action :subscribe do
      argument :id, :string, allow_nil?: false

      run fn input, _ ->
        Phoenix.PubSub.subscribe(@pubsub, topic(input.arguments.id))
        :ok
      end
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

    has_many :items, TeamShopping.Shopping.ListItem
  end

  def topic(list_id) when is_binary(list_id), do: "list:#{list_id}"
end
