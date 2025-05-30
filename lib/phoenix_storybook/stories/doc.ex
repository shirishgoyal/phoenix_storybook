defmodule PhoenixStorybook.Stories.Doc do
  @moduledoc """
  Functions to fetch component documentation and render it at HTML.
  """

  alias Phoenix.HTML.Safe, as: HTMLSafe
  alias PhoenixStorybook.Rendering.CodeRenderer
  alias PhoenixStorybook.Stories.Doc

  require Logger

  defstruct [:header, :body]

  @doc """
  Fetch component documentation from component source and format it as HTML.
  - For a live_component, fetches @moduledoc content
  - For a function component, fetches @doc content of the relevant function

  Output HTML is split in paragraphs and returned as a list of paragraphs.
  """
  def fetch_doc_as_html(story, stripped? \\ true) do
    case fetch_component_doc(story.storybook_type(), story) do
      :error ->
        nil

      doc ->
        case split_header(doc, stripped?) do
          [] -> nil
          [header] -> %Doc{header: format(header)}
          [header, body] -> %Doc{header: format(header), body: format(body)}
        end
    end
  end

  def fetch_component_doc(:component, module) do
    info = Function.info(module.function())
    fetch_function_doc(info[:module], {info[:name], info[:arity]})
  end

  def fetch_component_doc(:live_component, module) do
    fetch_module_doc(module.component())
  end

  defp fetch_function_doc(module, {fun, arity}) do
    case Code.fetch_docs(module) do
      {_, _, _, _, _, _, function_docs} ->
        case find_function_doc(function_docs, fun, arity) do
          map when is_map(map) -> map |> Map.values() |> Enum.at(0)
          _ -> nil
        end

      _ ->
        Logger.warning("could not fetch function docs from #{inspect(module)}")
        :error
    end
  end

  defp find_function_doc(docs, fun, arity) do
    Enum.find_value(
      docs,
      %{},
      fn
        {{:function, item_fun, item_arity}, _, _, doc, _} ->
          if fun == item_fun && arity == item_arity, do: doc, else: false

        _ ->
          false
      end
    )
  end

  defp fetch_module_doc(module) do
    case Code.fetch_docs(module) do
      {_, _, _, _, module_doc, _, _} ->
        case module_doc do
          map when is_map(map) -> map |> Map.values() |> Enum.at(0)
          _ -> nil
        end

      _ ->
        Logger.warning("could not fetch module doc from #{inspect(module)}")
        :error
    end
  end

  def strip_lv_attributes_doc(doc),
    do: (" " <> doc) |> String.split("## Attributes\n\n", trim: true) |> hd()

  def strip_lv_slots_doc(doc),
    do: (" " <> doc) |> String.split("## Slots\n\n", trim: true) |> hd()

  defp split_header(nil, _stripped?), do: []
  defp split_header(doc, false), do: String.split(doc, "\n\n", parts: 2, trim: true)

  defp split_header(doc, true) do
    doc |> strip_lv_attributes_doc() |> strip_lv_slots_doc() |> split_header(false)
  end

  defp format(doc) do
    doc |> Earmark.as_html!() |> highlight_code_blocks()
  end

  defp highlight_code_blocks(html) do
    regex = ~r/<pre><code(?:\s+class="(\w*)")?>([^<]*)<\/code><\/pre>/
    Regex.replace(regex, html, &highlight_code_block/3)
  end

  defp highlight_code_block(_full_match, lang, escaped_code) do
    code = escaped_code |> unescape_html() |> IO.iodata_to_binary()

    lang =
      case lang do
        "elixir" -> :elixir
        "heex" -> :heex
        "" -> code |> String.trim_leading() |> guess_lang()
        _ -> :unknown
      end

    CodeRenderer.render_code_block(code, lang, trim: false)
    |> HTMLSafe.to_iodata()
  end

  defp guess_lang("<" <> _), do: :heex
  defp guess_lang(_code), do: :elixir

  entities = [{"&amp;", ?&}, {"&lt;", ?<}, {"&gt;", ?>}, {"&quot;", ?"}, {"&#39;", ?'}]

  for {encoded, decoded} <- entities do
    defp unescape_html(unquote(encoded) <> rest), do: [unquote(decoded) | unescape_html(rest)]
  end

  defp unescape_html(<<c, rest::binary>>), do: [c | unescape_html(rest)]
  defp unescape_html(<<>>), do: []
end
