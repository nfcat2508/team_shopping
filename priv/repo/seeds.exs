# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     TeamShopping.Repo.insert!(%TeamShopping.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

defmodule Seeds do
  import Ecto.Query, only: [from: 2]

  alias TeamShopping.Accounts.User
  alias TeamShopping.Repo

  def add_user!(email, password) do
    password
    |> AshAuthentication.BcryptProvider.hash()
    |> elem(1)
    |> (&%User{email: email, hashed_password: &1}).()
    |> Repo.insert!()

    Repo.one!(from(u in User, where: u.email == ^email))
  end
end

user_1 = Seeds.add_user!("user1@test.de", "password4242")
user_2 = Seeds.add_user!("user2@test.de", "password4242")
user_3 = Seeds.add_user!("user3@test.de", "password4242")

team_12 = TeamShopping.Teams.create!("Shoppers_12", user_1.id)
team_13 = TeamShopping.Teams.create!("Shoppers_13", user_3.id)

TeamShopping.Teams.add_member!(team_12.id, user_1.id, %{"name" => "Thea"})
TeamShopping.Teams.add_member!(team_12.id, user_2.id, %{"name" => "Hanna"})
TeamShopping.Teams.add_member!(team_13.id, user_1.id, %{"name" => "Miss T"})
TeamShopping.Teams.add_member!(team_13.id, user_3.id, %{"name" => "Olga"})
