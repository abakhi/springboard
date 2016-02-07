defmodule SpringBoard.Event do
  @moduledoc "Struct for broadcasting events"
  defstruct [:type, :data, :metadata]
end
