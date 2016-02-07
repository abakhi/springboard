defmodule SpringBoard.AppSerializer do
  use SpringBoard.Serializer

  attributes [
    :name,
    :email,
    :webhook_url,
    :verified,
    :link
  ]

  assoc_attributes [:user, :api_keys]
end
