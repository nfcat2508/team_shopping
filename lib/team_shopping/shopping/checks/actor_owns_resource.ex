defmodule TeamShopping.Shopping.Checks.ActorOwnsResource do
  use Ash.Policy.SimpleCheck

  def describe(_) do
    "actor owns resource"
  end

  def match?(
        %TeamShopping.Accounts.User{id: id} = _actor,
        %{resource: TeamShopping.Shopping.List} = context,
        _opts
      ) do
    context.subject.data.creator_id == id
  end

  def match?(_, _, _), do: false
end
