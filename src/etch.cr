require "./etch/*"

module Etch
  VERSION    = {{ `shards version #{__DIR__}/..`.stringify.chomp }}
  BUILD_DATE = {{ `date +%F`.stringify.chomp }}
  BUILD_HASH = {{ `git rev-parse HEAD`.stringify[0...8] }}
end
