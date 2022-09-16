defmodule TreeStorybook.Event.EventComponent do
  use PhxLiveStorybook.Entry, :component
  def function, do: &EventComponent.component/1

  def description, do: "event component description"

  def attributes do
    [
      %Attr{
        id: :label,
        type: :string,
        doc: "event component label",
        required: true
      }
    ]
  end

  def stories do
    [
      %Story{
        id: :hello,
        description: "Hello story",
        attributes: %{label: "hello"}
      }
    ]
  end
end