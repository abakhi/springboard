defmodule SpringBoard.ApiKeySerializer do
  use SpringBoard.Serializer

  attributes [
    :secret_key,
    :public_key,
    :env,
  ]

  assoc_attribute :app
end
