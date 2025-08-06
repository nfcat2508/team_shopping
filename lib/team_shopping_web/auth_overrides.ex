defmodule TeamShoppingWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, "/images/teamshopping_light.png"
    set :dark_image_url, "/images/teamshopping_dark.png"
  end
end
