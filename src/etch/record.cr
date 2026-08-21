require "./level"
require "./options"
require "./value"

module Etch
  # The immutable structural representation of a single logged occurrence, comprising all of underlying consituent Item fields.
  struct Record
    record Timestamp, value : Time
    record Severity, value : Level
    record Caller, value : String
    record Prefix, value : String
    record Message, value : String
    record Payload, key : String, value : Value

    # A specific structural Item field in a Record.
    alias Item = Timestamp | Severity | Caller | Prefix | Message | Payload
    # Enumerable mixin provides traversal and iteration methods
    include Enumerable(Item)

    @items : Array(Item)

    # Captures one Record from logger config and payload fields. Bound payload fields always preced callsite payload fields.
    #
    # Builtin entries are normalized and ommitted here if unset.
    def initialize(
      level : Level,
      msg,
      bound_fields : Fields,
      call_fields : Fields,
      timestamp : Time?,
      file : String,
      line : Int32,
      *,
      report_timestamp : Bool,
      time_function : TimeFunction,
      report_caller : Bool,
      caller_formatter : CallerFormatter?,
      prefix : String,
    )
      items = [] of Item

      if report_timestamp
        items << Timestamp.new(time_function.call(timestamp || Time.local))
      end

      items << Severity.new(level) unless level.none?

      if report_caller
        formatter = caller_formatter || SHORT_CALLER_FORMATTER
        items << Caller.new(formatter.call(file, line, ""))
      end

      items << Prefix.new(prefix) unless prefix.empty?

      message = msg.to_s
      items << Message.new(message) unless message.empty?

      bound_fields.each do |k, v|
        items << Payload.new(k, v)
      end

      call_fields.each do |k, v|
        items << Payload.new(k, v)
      end

      @items = items
    end

    # Yields semantic *items* in their rendering order.
    def each(& : Item ->) : Nil
      @items.each { |item| yield item }
    end
  end
end
