defmodule TeamShopping.Teams do
  use Ash.Domain

  resources do
    resource TeamShopping.Teams.Member do
      define :add_member, args: [:team_id, :user_id], action: :create
      define :remove_member, action: :destroy
      define :team_members, args: [:team_id], action: :by_team_id
    end

    resource TeamShopping.Teams.Team do
      define :create, args: [:name, :creator_id], action: :create
      define :get, args: [:id], action: :by_id
      define :delete, action: :destroy
    end
  end
end
