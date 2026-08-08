defmodule Blog.Card do
  @moduledoc """
  Builds the 1200x630 share card for a post as SVG, and rasterises it to PNG.

  Cards are produced on request rather than checked in, so a post's card can
  never fall out of step with its title or the brand. Results are cached
  against a hash of the post content, so a card is only drawn once per revision.
  """

  require Logger

  alias Blog.Mark

  @width 1200
  @height 630
  @table __MODULE__

  # Brand tokens, resolved from OKLCH to sRGB: librsvg does not parse oklch().
  @paper "#faf7f3"
  @ink "#271f18"
  @ink_3 "#87807a"
  @rule "#d9d4ce"
  @rule_2 "#c1bbb3"
  @signal "#d33a0c"

  @cell 22
  @gap 10

  @doc """
  The PNG bytes for a post, drawn on first use and cached against `revision`.
  """
  @spec png(String.t(), map()) :: {:ok, binary(), String.t()} | {:error, term()}
  def png(slug, post) do
    revision = revision(slug, post)

    case lookup(revision) do
      {:ok, png} ->
        {:ok, png, revision}

      :miss ->
        with {:ok, png} <- rasterise(svg(slug, post)) do
          store(revision, png)
          {:ok, png, revision}
        end
    end
  end

  @doc "A short, stable tag for a card's current content."
  @spec revision(String.t(), map()) :: String.t()
  def revision(slug, post) do
    :crypto.hash(:sha256, :erlang.term_to_binary({slug, post.title, post.date, post.reading_time}))
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end

  @spec svg(String.t(), map()) :: String.t()
  def svg(slug, post) do
    {size, lines} = fit(post.title)
    leading = round(size * 1.06)
    baseline = 372 - (length(lines) - 1) * leading

    titles =
      lines
      |> Enum.with_index()
      |> Enum.map_join("", fn {line, index} ->
        ~s(<text x="72" y="#{baseline + index * leading}" class="title">#{escape(line)}</text>)
      end)

    extent = Mark.extent(@cell, @gap)
    mark_x = @width - 72 - extent
    mark_y = 372 - extent + 12

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}">
      <style>
        .title { font-family: "Familjen Grotesk"; font-weight: 700; font-size: #{size}px; letter-spacing: -0.03em; fill: #{@ink}; }
        .label { font-family: "JetBrains Mono"; font-size: 20px; letter-spacing: 2.6px; fill: #{@ink_3}; }
        .wordmark { fill: #{@ink}; }
        .lit { fill: #{@signal}; }
        .dark { fill: none; stroke: #{@rule_2}; stroke-width: 1.5; }
      </style>

      <rect width="#{@width}" height="#{@height}" fill="#{@paper}" />

      <circle cx="78" cy="71" r="6" fill="#{@signal}" />
      <text x="98" y="78" class="label wordmark">FILIPECABACO.COM</text>

      #{titles}

      <g transform="translate(#{mark_x}, #{mark_y})">#{Mark.rects(slug, @cell, @gap)}</g>

      <line x1="72" y1="502" x2="#{@width - 72}" y2="502" stroke="#{@rule}" stroke-width="1" />
      <text x="72" y="552" class="label">#{escape(post.date)}</text>
      #{duration(post.reading_time)}
    </svg>
    """
  end

  defp rasterise(svg) do
    with {:ok, binary} <- run_rsvg(svg) do
      {:ok, binary}
    end
  end

  defp run_rsvg(svg) do
    case System.find_executable("rsvg-convert") do
      nil ->
        Logger.error("rsvg-convert not found; cannot render share cards")
        {:error, :no_rasteriser}

      binary ->
        input = Path.join(System.tmp_dir!(), "card-#{System.unique_integer([:positive])}.svg")
        output = input <> ".png"
        File.write!(input, svg)

        try do
          args = ["--width", "#{@width}", "--height", "#{@height}", "--format", "png", "--output", output, input]

          case System.cmd(binary, args, env: font_env(), stderr_to_stdout: true) do
            {_, 0} -> {:ok, File.read!(output)}
            {message, code} -> {:error, {:rsvg, code, message}}
          end
        after
          File.rm(input)
          File.rm(output)
        end
    end
  end

  # Point fontconfig at the fonts shipped in priv, so the card renders with the
  # site's typefaces whether or not they are installed on the host.
  defp font_env do
    dir = Application.app_dir(:blog, "priv/fonts")
    cache = Path.join(System.tmp_dir!(), "fontconfig")
    conf = Path.join(cache, "fonts.conf")

    File.mkdir_p!(cache)

    unless File.exists?(conf) do
      File.write!(conf, """
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <dir>#{dir}</dir>
        <cachedir>#{cache}</cachedir>
      </fontconfig>
      """)
    end

    [{"FONTCONFIG_FILE", conf}]
  end

  # The title has to clear the mark on the right, so each size gets the line
  # length that actually fits the space beside it.
  @steps [{84, 19}, {70, 24}, {62, 29}]

  defp fit(title) do
    Enum.find_value(@steps, fn {size, limit} ->
      lines = wrap(title, limit)
      if length(lines) <= 3 and Enum.all?(lines, &(String.length(&1) <= limit)), do: {size, lines}
    end) || {56, wrap(title, 33)}
  end

  # SVG has no line breaking, so the title is wrapped here.
  defp wrap(title, limit) do
    title
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce([], fn word, acc ->
      case acc do
        [] ->
          [word]

        [current | rest] ->
          candidate = current <> " " <> word
          if String.length(candidate) <= limit, do: [candidate | rest], else: [word, current | rest]
      end
    end)
    |> Enum.reverse()
    |> Enum.take(4)
  end

  defp duration(nil), do: ""

  defp duration(minutes),
    do: ~s(<text x="#{@width - 72}" y="552" class="label" text-anchor="end">#{minutes} MIN READ</text>)

  defp escape(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  @doc """
  Creates the card cache. Called from the application master so the table
  outlives the request processes that read and write it.
  """
  def init_cache do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    end

    :ok
  end

  defp lookup(revision) do
    case :ets.lookup(@table, revision) do
      [{^revision, png}] -> {:ok, png}
      _ -> :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp store(revision, png) do
    :ets.insert(@table, {revision, png})
    :ok
  rescue
    ArgumentError -> :ok
  end
end
