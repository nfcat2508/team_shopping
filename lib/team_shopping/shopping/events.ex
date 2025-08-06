defmodule TeamShopping.Shopping.Events do
  defmodule ItemAdded do
    defstruct item: nil
  end

  defmodule ItemUpdated do
    defstruct item: nil
  end

  defmodule ItemDeleted do
    defstruct item_id: nil
  end

  defmodule ItemCleared do
    defstruct item_id: nil
  end

  defmodule ItemReopened do
    defstruct item_id: nil
  end
end
