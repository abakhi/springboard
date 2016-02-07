defmodule SpringBoard.Web.Controller do
  @moduledoc """
  Shared controller utilities
  """
  @doc """
  Extracts associated fields to preload from the request's `expand` field.

  ## Example
  GET $URL/v1/users/usr_d2cb1a7fc57fec8deb41c51ac0fc7315?expand=cards,identity_card,transfers,wallets,bank_accounts

  Should try to expand the identity_card, wallets, bank_accounts, and cards
  fields associated to the user.
  """
  # NOTE: not in use. Firsty verify that Phoenix does not cleanup params
  defmacro __using__(_) do
    quote do

      def action(conn, _) do
        params =
        (Enum.map(conn.params, fn {k, v} ->
              {String.strip(k), String.strip(v)} end) |> Map.new)
        apply(__MODULE__, action_name(conn), [conn, params])
      end
    end
  end

  @spec parse_expand_qs(Map.t) :: Enum.t
  def parse_expand_qs(expand_fields) do
    if expand_fields && (String.length(expand_fields) > 0) do
      String.split(expand_fields, ",")
      |> Enum.map(&(String.downcase(&1) |> String.to_atom))
    else
      []
    end
  end
end
