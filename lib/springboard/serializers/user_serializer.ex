defmodule SpringBoard.UserSerializer do
  use SpringBoard.Serializer

  attributes [
    :first_name,
    :last_name,
    :phone_number,
    :email,
    :gcm_id,
    :account_type,
    :verified
  ]

  assoc_attribute :apps
end
