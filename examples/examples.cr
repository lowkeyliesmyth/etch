require "../src/etch"

# Runnable reference consumers examples of Etch's public API, also functioning as a full e2e test.
module Examples
  class UnknownExample < Exception
    def initialize(name : String, available : Array(String))
      super("unknown example #{name.inspect}. available examples: #{available.join(", ")}")
    end
  end

  @@registry = {} of String => Proc(IO, Nil)

  # Register *block* as the example named *name*.
  def self.register(name : String, &block : IO -> Nil) : Nil
    @@registry[name] = block
  end

  # Give the sorted list of examples to pick from.
  def self.names : Array(String)
    @@registry.keys.sort!
  end

  # Run the example *name* consumer, sending its output to *io*.
  #
  # Raise when *name* is not a registered example consumer.
  def self.run(name : String, io : IO) : Nil
    block = @@registry[name]?
    raise UnknownExample.new(name, names) unless block
    block.call(io)
  end
end

# Example consumers get self-registered when required. One line per example consumer.
require "./basic/default"
require "./basic/new"
require "./config/format"
require "./config/options"
