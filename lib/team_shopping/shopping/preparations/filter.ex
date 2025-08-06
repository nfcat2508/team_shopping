defmodule TeamShopping.Shopping.Preparations.Filter do
  use Ash.Resource.Preparation

  # transform and validate opts
  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def prepare(query, _opts, _context) do
    status = Ash.Query.get_argument(query, :status)
    name_substring = Ash.Query.get_argument(query, :name_substring)

    query =
      if status do
        Ash.Query.filter(query, status == ^status)
      else
        query
      end

    if name_substring do
      Ash.Query.filter(query, contains(name, ^name_substring))
    else
      query
    end
  end
end
