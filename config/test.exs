import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :team_shopping, TeamShopping.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "team_shopping_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :team_shopping, TeamShoppingWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "3bI3Pu+pTP7bAddCE4msqbs3JACHqYp0kMDAHMXL5WyjApjSqLcLypjXo+lyU5Ft",
  server: false

# In test we don't send emails
config :team_shopping, TeamShopping.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# This ensures that Ash does not spawn tasks when executing your requests, which is necessary for doing transactional tests with AshPostgres
config :ash, :disable_async?, true

# If you are using Ecto's transactional features to ensure that your tests all run in a transaction, Ash will detect that it had notifications to send (if you have any notifiers set up) but couldn't because it was still in a transaction. The default behavior when notifications are missed is to warn. However, this can get pretty noisy in tests
config :ash, :missed_notifications, :ignore

config :ash, :pub_sub, debug?: true
