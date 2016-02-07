defmodule SpringBoard.UUID do
  @moduledoc """
    Helper module for generating unique user ids. The UUID generated here
    differs from Ecto.UUID by removing all the dashes/separators.

    It also supports optional UUID prefixes.

    # Examples:
    iex> UUID.generate("evt_")
    iex> evt_9vbkjhfkfcjddfk87654yu
    """
  import SpringBoard

  def generate_prefix(model) when is_map(model) do
    generate_prefix(model.__struct__)
  end

  def generate_prefix(thing) do
  (thing
   |> do_generate_prefix
   |> String.downcase) <> "_"
  end

  defp do_generate_prefix(word) do
    case String.length(word) do
      wc when wc <= 3 ->
        word
      wc when wc >= 4 ->
        String.slice(word, 0..2)
    end
  end

  def generate(prefix \\ "", allow_caps? \\ false) do
    uuid = :erlang.system_time |> to_string |> md5

    unless allow_caps? do
      prefix <> random_casetoggle(uuid)
    else
      prefix <> uuid
    end
  end

  @doc """
  Randomly upcases a character in a string.

  This is meant to be used in conjunction with ``UUID.geneate``
  """
  def random_casetoggle(word, to_case \\ :lower) do
    if is_list(word) do
      do_random_casetoggle(word, [], to_case)
    else
      String.split(word,"") |> do_random_casetoggle([], to_case)
    end
  end

  defp do_random_casetoggle([], xs, _to_case) do
    xs |> Enum.reverse |> Enum.join("")
  end

  defp do_random_casetoggle([""|rest], xs, to_case) do
    do_random_casetoggle(rest, xs, to_case)
  end

  defp do_random_casetoggle([x|rest], xs, to_case) do
    new_x = toggle_case(to_case, x)
    do_random_casetoggle(rest, [new_x|xs], to_case)
  end

  defp toggle_case(:lower, x) do
    to_lower? = upper_case?(x) && Enum.random([true, false])
    if to_lower? do
      to_string(x) |> String.downcase
    else
      to_string(x)
    end
  end

  defp toggle_case(:upper, x) do
    to_upper? = lower_case?(x) && Enum.random([true, false])
    if to_upper? do
      to_string(x) |> String.upcase
    else
      to_string(x)
    end
  end
end
