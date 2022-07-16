import Config

if System.get_env("PHX_SERVER") do
  config :blog, BlogWeb.Endpoint, server: true
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "filipecabaco.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :blog, BlogWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: ["https://filipecabaco.com"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :blog, :github_token, System.get_env("GITHUB_API_TOKEN")
end
