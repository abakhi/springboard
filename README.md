# Springboard

## TODO

- Documentation
- Tests
- CI build status/badge
- Sample/demo app using SpringBoard
- Make models ultra-light
- Add event bus
- Phoenix mixins in web.ex
- Phone number parser
- Publish on hex.pm

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add springboard to your list of dependencies in `mix.exs`:

        def deps do
          [{:springboard, "~> 0.0.1"}]
        end

  2. Ensure springboard is started before your application:

        def application do
          [applications: [:springboard]]
        end
