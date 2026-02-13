defmodule Blog.Images.Strategies.TypographicCard do
  @moduledoc """
  Generates a simple typographic card with title, tags, and description.
  Fallback strategy when no specific visual content is available.
  """

  alias Blog.Posts

  @behaviour Blog.Images.Strategy

  @card_width 1200
  @card_height 630
  @background_color "#ffffff"
  @text_color "#111827"
  @tag_bg_color "#e0e7ff"
  @tag_text_color "#3730a3"

  @doc """
  Generate a typographic card image for the post.
  """
  @impl true
  def generate(post_content, post_title) do
    title = Posts.title(post_content)
    description = Posts.description(post_content) |> truncate(200)
    tags = Posts.tags(post_content)

    output_path = image_path(post_title)
    ensure_output_dir(output_path)

    # For now, return a placeholder implementation
    # TODO: Implement actual image generation using Vix or Mogrify
    create_placeholder(output_path, title, description, tags)
  end

  # Private functions

  defp truncate(text, max_length) when byte_size(text) <= max_length, do: text

  defp truncate(text, max_length) do
    text
    |> String.slice(0, max_length)
    |> String.trim()
    |> Kernel.<>("...")
  end

  defp ensure_output_dir(output_path) do
    output_path
    |> Path.dirname()
    |> File.mkdir_p!()
  end

  defp image_path(post_title) do
    Path.join([
      :code.priv_dir(:blog),
      "static",
      "images",
      "generated",
      "#{post_title}.png"
    ])
  end

  defp create_placeholder(output_path, title, description, tags) do
    # Create a simple SVG as placeholder
    svg_content = """
    <svg width="#{@card_width}" height="#{@card_height}" xmlns="http://www.w3.org/2000/svg">
      <rect width="#{@card_width}" height="#{@card_height}" fill="#{@background_color}"/>

      <!-- Title -->
      <text x="60" y="200" font-family="monospace" font-size="48" font-weight="600" fill="#{@text_color}">
        #{escape_xml(String.slice(title, 0, 40))}
      </text>

      <!-- Description -->
      <text x="60" y="280" font-family="sans-serif" font-size="24" fill="#6b7280">
        #{escape_xml(String.slice(description, 0, 80))}
      </text>

      <!-- Tags -->
      #{render_tags(tags)}
    </svg>
    """

    filename = output_path |> Path.basename(".png") |> Kernel.<>(".svg")
    File.write!(output_path <> ".svg", svg_content)
    {:ok, "/images/generated/#{filename}"}
  end

  defp render_tags(tags) do
    tags
    |> Enum.with_index()
    |> Enum.map(fn {tag, index} ->
      x = 60 + index * 120
      y = 380

      """
      <rect x="#{x}" y="#{y}" width="110" height="40" rx="20" fill="#{@tag_bg_color}"/>
      <text x="#{x + 15}" y="#{y + 27}" font-family="monospace" font-size="16" fill="#{@tag_text_color}">
        #{escape_xml(tag)}
      </text>
      """
    end)
    |> Enum.join("\n")
  end

  defp escape_xml(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
