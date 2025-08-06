defmodule TeamShoppingWeb.Router do
  use TeamShoppingWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TeamShoppingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  scope "/", TeamShoppingWeb do
    get "/serviceworker.js", ServiceWorker, :run
  end

  scope "/", TeamShoppingWeb do
    pipe_through :browser

    get "/", RedirectController, :redirect_to_lists

    sign_in_route(
      on_mount: [{TeamShoppingWeb.LiveUserAuth, :live_no_user}],
      #      register_path: "/register",
      #      reset_path: "/reset",
      overrides: [TeamShoppingWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )

    sign_out_route AuthController
    auth_routes_for TeamShopping.Accounts.User, to: AuthController

    reset_route overrides: [
                  TeamShoppingWeb.AuthOverrides,
                  AshAuthentication.Phoenix.Overrides.Default
                ]
  end

  scope "/", TeamShoppingWeb do
    pipe_through [:browser, TeamShoppingWeb.ReturnToPlug]

    ash_authentication_live_session :authentication_required,
      on_mount: {TeamShoppingWeb.LiveUserAuth, :live_user_required} do
      live "/lists", ListsLive, :lists
      live "/lists/new", ListsLive, :new_list
      live "/lists/:id/edit", ListsLive, :edit_list
      live "/lists/:id", ListItemsLive, :list
      live "/lists/:id/items", ListItemsLive, :items
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", TeamShoppingWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:team_shopping, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TeamShoppingWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
