defmodule TeamShopping.Accounts.User do
  use Ash.Resource,
    domain: TeamShopping.Accounts,
    data_layer: AshPostgres.DataLayer,
    # If using policies, enable the policy authorizer:
    # authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
  end

  actions do
    defaults [:read]
  end

  authentication do
    strategies do
      password :password do
        identity_field :email

        registration_enabled? false
        #     resettable do
        #      sender TeamShopping.Accounts.User.Senders.SendPasswordResetEmail
        #    end
      end
    end

    tokens do
      enabled? true
      token_resource TeamShopping.Accounts.Token
      signing_secret TeamShopping.Accounts.Secrets
      require_token_presence_for_authentication? true
      store_all_tokens? true
    end
  end

  postgres do
    table "users"
    repo TeamShopping.Repo
  end

  identities do
    identity :unique_email, [:email]
  end

  relationships do
    many_to_many :teams, TeamShopping.Teams.Team do
      through TeamShopping.Teams.Member
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :team_id
    end
  end

  # If using policies, add the following bypass:
  # policies do
  #   bypass AshAuthentication.Checks.AshAuthenticationInteraction do
  #     authorize_if always()
  #   end
  # end
end
