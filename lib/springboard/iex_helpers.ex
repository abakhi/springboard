defmodule SpringBoard.IExHelpers do
  @doc "Recompiles and reloads app"
  def rr(app \\ nil) do
    IEx.Helpers.recompile
    app = app || :application.get_application
    # restart app
    :ok = Application.ensure_started(app)
  end

  @doc "Lookup documentation on Erlang modules etc"
  def hh(thing), do: Erlh.h thing

  if Code.ensure_loaded(Mix) && Mix.env == :dev do
    import Mex
    Mex.set_width 160
  end
end
