defmodule TeamShopping.Const do
  @moduledoc """
  This module defines some constants used in several test files
  """

  @invalid_chars [
    "!",
    "\"",
    "'",
    "§",
    "$",
    "%",
    "&",
    "(",
    ")",
    "=",
    "?",
    "+",
    "*",
    "<",
    ">",
    "/",
    "\\",
    "{",
    "}",
    "^",
    "[",
    "]",
    "|"
  ]

  def invalid_chars(), do: @invalid_chars
end
