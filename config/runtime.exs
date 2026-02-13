import Config

# Load .env file in development and test environments
if config_env() in [:dev, :test] do
  env_file = Path.expand(".env", File.cwd!())

  if File.exists?(env_file) do
    env_file
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.each(fn line ->
      case String.split(line, "=", parts: 2) do
        [key, value] ->
          key = String.trim(key)
          value = String.trim(value)
          System.put_env(key, value)

        _ ->
          :ok
      end
    end)
  end
end

config :blog, :github_token, System.get_env("GITHUB_API_TOKEN") || System.get_env("GITHUB_TOKEN") || ""

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
    check_origin: ["https://filipecabaco.com", "https://filipe-cabaco-blog.fly.dev"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end
