require "./etch/*"

module Etch
  VERSION    = {{ `shards version #{__DIR__}/..`.stringify.chomp }}
  BUILD_DATE = {{ `date +%F`.stringify.chomp }}
  BUILD_HASH = {{ `git rev-parse HEAD`.stringify[0...8] }}

  # Runs *block*, returning the appropriate process exit status:
  # - 1 when it ends in `FatalError`
  # - 0 otherwise
  #
  # Use this when an application needs to flush or cleanup before terminating.
  def self.status(&) : Int32
    yield
    0
  rescue FatalError
    1
  end

  # Runs *block*, terminating the process with status 1 if it ends in a `FatalError`.
  # This is how a fatal record ends the program without `Logger#fatal` calling `exit` itself directly.
  def self.run(&) : Nil
    statuscode = status { yield }
    exit(statuscode) unless statuscode.zero?
  end
end
