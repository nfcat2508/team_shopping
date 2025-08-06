defmodule TeamShopping.Accounts do
  use Ash.Domain

  resources do
    resource TeamShopping.Accounts.User
    resource TeamShopping.Accounts.Token
  end
end
