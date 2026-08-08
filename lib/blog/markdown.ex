defmodule Blog.Markdown do
  @moduledoc """
  Renders post markdown to HTML, highlighting code fences with Makeup and
  collecting the headings for the contents rail.
  """

  require Logger

  @type heading :: %{level: 2 | 3, id: String.t(), text: String.t()}

  @doc """
  Renders markdown to `{:ok, html, headings}`, or `{:error, reason}`.
  """
  @spec render(String.t()) :: {:ok, String.t(), [heading()]} | {:error, String.t()}
  def render(markdown) when is_binary(markdown) do
    case Earmark.Parser.as_ast(markdown) do
      {:ok, ast, _messages} ->
        ast = Enum.map(ast, &walk/1)
        {:ok, Earmark.Transform.transform(ast), headings(ast)}

      {:error, _ast, messages} ->
        Logger.error("Failed to parse markdown: #{inspect(messages)}")
        {:error, "Failed to parse markdown"}
    end
  end

  defp walk({"pre", _atts, [{"code", code_atts, [source], _code_meta}], _meta}) when is_binary(source) do
    lang = language(code_atts)

    body =
      case highlight(source, lang) do
        {:ok, inner} -> {"code", [{"class", "code__source"}], [inner], %{verbatim: true}}
        :error -> {"code", [{"class", "code__source"}], [source], %{}}
      end

    {"div", [{"class", "code"}], [code_bar(lang), {"pre", [], [body], %{}}], %{}}
  end

  defp walk({tag, atts, children, meta}) when tag in ["h2", "h3"] do
    text = text_of(children)
    id = slug(text)
    anchor = {"a", [{"class", "heading__anchor"}, {"href", "#" <> id}, {"aria-label", "Link to #{text}"}], ["#"], %{}}

    {tag, [{"id", id} | atts], Enum.map(children, &walk/1) ++ [anchor], meta}
  end

  defp walk({"table", atts, children, meta}) do
    {"div", [{"class", "table-scroll"}], [{"table", atts, Enum.map(children, &walk/1), meta}], %{}}
  end

  defp walk({"img", atts, children, meta}) do
    {"img", atts ++ [{"loading", "lazy"}, {"decoding", "async"}], children, meta}
  end

  defp walk({tag, atts, children, meta}), do: {tag, atts, Enum.map(children, &walk/1), meta}
  defp walk(other), do: other

  defp code_bar(nil), do: copy_bar([])

  defp code_bar(lang), do: copy_bar([{"span", [{"class", "code__lang"}], [lang], %{}}])

  defp copy_bar(prefix) do
    button =
      {"button",
       [
         {"type", "button"},
         {"class", "code__copy"},
         {"data-copy", "true"},
         {"aria-label", "Copy code to clipboard"}
       ], ["copy"], %{}}

    {"div", [{"class", "code__bar"}], prefix ++ [button], %{}}
  end

  defp highlight(_source, nil), do: :error

  defp highlight(source, lang) do
    case Makeup.Registry.fetch_lexer_by_name(lang) do
      {:ok, {lexer, opts}} ->
        {:ok, Makeup.highlight_inner_html(source, lexer: lexer, lexer_options: opts)}

      :error ->
        :error
    end
  rescue
    e ->
      Logger.warning("Failed to highlight #{lang} block: #{Exception.message(e)}")
      :error
  end

  defp language(atts) do
    case List.keyfind(atts, "class", 0) do
      {"class", class} ->
        class
        |> String.split(" ", trim: true)
        |> Enum.map(&String.replace_prefix(&1, "language-", ""))
        |> List.first()

      _ ->
        nil
    end
  end

  defp headings(ast) do
    ast
    |> Enum.flat_map(&collect_headings/1)
  end

  defp collect_headings({tag, atts, children, _meta}) when tag in ["h2", "h3"] do
    case List.keyfind(atts, "id", 0) do
      {"id", id} ->
        level = if tag == "h2", do: 2, else: 3
        [%{level: level, id: id, text: children |> Enum.reject(&anchor?/1) |> text_of()}]

      _ ->
        []
    end
  end

  defp collect_headings({_tag, _atts, children, _meta}) when is_list(children),
    do: Enum.flat_map(children, &collect_headings/1)

  defp collect_headings(_), do: []

  defp anchor?({"a", atts, _, _}), do: List.keyfind(atts, "class", 0) == {"class", "heading__anchor"}
  defp anchor?(_), do: false

  defp text_of(nodes) when is_list(nodes), do: nodes |> Enum.map(&text_of/1) |> Enum.join()
  defp text_of(text) when is_binary(text), do: text
  defp text_of({_tag, _atts, children, _meta}), do: text_of(children)
  defp text_of(_), do: ""

  defp slug(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "section"
      slug -> slug
    end
  end
end
