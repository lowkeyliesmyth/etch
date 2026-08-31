require "./value"

module Etch
  # Raised after a fatal record is logged.
  # Holds the optional message and the fatal record's fields.
  class FatalError < Exception
    getter fields : Fields

    def initialize(message : String? = nil, @fields : Fields = Fields.new)
      super(message)
    end
  end
end
