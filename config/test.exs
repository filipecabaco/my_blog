import Config

config :blog, BlogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ljEslM5fxL4Vj9gkljtfuIUvoRywW6Tms8ZpnJEU8Pt0VWjAGgzpxxGadPvthoOs",
  server: false

config :blog, :github_token, "test-token"
config :blog, :skip_warmup, true

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
