defmodule TeamShopping.AssertHelper do
  @moduledoc """
  This module defines some helper functions to be used with ExUnit.assert 
  """

  @doc """
  Expects exactly one error and returns its message, raises if no or more than one error present
  """
  def message(error) do
    single_error(error.errors).message
  end

  defp single_error([error]), do: error
  defp single_error([]), do: raise("An error was expected, but no error present")

  defp single_error([_a, _b | _h]),
    do: raise("Exactly one  error was expected, but multiple errors present")
end
