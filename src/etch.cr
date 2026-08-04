require "./etch/*"

module Etch
  VERSION    = {{ `shards version #{__DIR__}/..`.stringify.chomp }}
  BUILD_DATE = {{ `date +%F`.stringify.chomp }}
  BUILD_HASH = {{ `git rev-parse HEAD`.stringify[0...8] }}

  # Runs *block*, rescuing `FatalError` and exiting the process with status 1. So fatal terminates the program without etch directly calling `exit`.
  def self.run(&) : Nil
    yield
  rescue FatalError
    exit 1
  end
end
