require "./etch/*"

module Etch
  VERSION    = {{ `shards version #{__DIR__}/..`.stringify.chomp }}
  BUILD_DATE = {{ `date +%F`.stringify.chomp }}
  BUILD_HASH = {{ `git rev-parse HEAD`.stringify[0...8] }}

  # Raised after a fatal record is logged.
  # Carries the optional message and the fatal record's fields
  class FatalError < Exception
    getter fields : Array(Tuple(String, String))

    def initialize(message : String? = nil, @fields : Array(Tuple(String, String)) = [] of Tuple(String, String))
      super(message)
    end
  end
end
