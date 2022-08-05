defmodule PhxLiveStorybook.Quotes.PageQuotes do
  @moduledoc false

  alias Phoenix.HTML.Safe
  alias PhxLiveStorybook.{Entries, PageEntry}

  @doc false
  # Precompiling component preview & code snippet for every component / story couple.
  def page_quotes(entries) do
    page_quotes =
      for %PageEntry{module: module, navigation: navigation} <- Entries.all_leaves(entries),
          navigation = Enum.map(navigation, &elem(&1, 0)),
          navigation = if(navigation == [], do: [nil], else: navigation),
          tab <- navigation do
        quote do
          @impl PhxLiveStorybook.BackendBehaviour
          def render_page(unquote(module), unquote(tab)) do
            unquote(module.render(%{tab: tab}) |> to_raw_html())
          end
        end
      end

    default_quote =
      quote do
        @impl PhxLiveStorybook.BackendBehaviour
        def render_page(module, tab) do
          raise "unknown tab #{inspect(tab)} for module #{inspect(module)}"
        end
      end

    page_quotes ++ [default_quote]
  end

  defp to_raw_html(heex) do
    heex
    |> Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> Phoenix.HTML.raw()
  end
end
