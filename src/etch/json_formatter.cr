require "json"
require "./formatter"
require "./level"
require "./time"
require "./record"

module Etch
  # Renders a log record as a single JSON object.
  #
  # No styling is applied here because it's JSON. Styles are only applied to the `Text` formatter.
  struct JSONFormatter
    # Fallback for a value that JSON just can't represent
    INVALID_VALUE = "invalid value"

    def initialize(@time_format : String)
    end

    # Renders *record* as one newline terminted JSON object.
    #
    # Duped keys are preserved in order.
    def render(record : Record) : String
      String.build do |io|
        JSON.build(io) do |json|
          json.object do
            record.each { |item| write_item(json, item) }
          end
        end
        io << '\n'
      end
    end

    # Writes one structural Record *item* to *json*.
    #
    private def write_item(json : JSON::Builder, item : Record::Item) : Nil
      case item
      in Record::Timestamp
        json.field(TIMESTAMP_KEY, item.value.to_s(@time_format))
      in Record::Severity
        json.field(LEVEL_KEY, item.value.to_s)
      in Record::Caller
        json.field(CALLER_KEY, item.value)
      in Record::Prefix
        json.field(PREFIX_KEY, item.value)
      in Record::Message
        json.field(MESSAGE_KEY, item.value)
      in Record::Payload
        json.field(item.key) { write_value(json, item.value) }
      end
    end

    # Writes a field *value* in its *json* form.
    #
    # Time is rendered as a RFC3339-nano format. Non-finite floats are degraded to a fallback invalid value without raising.
    private def write_value(json : JSON::Builder, value : Value) : Nil
      case value
      in Nil       then json.null
      in Bool      then json.bool(value)
      in Int64     then json.number(value)
      in Float64   then value.finite? ? json.number(value) : json.string(INVALID_VALUE)
      in String    then json.string(value)
      in Time      then json.string(value.to_s(TimeFormat::RFC3339_NANO))
      in Exception then json.string(value.message.to_s)
      in Level     then json.string(value.to_s)
      end
    end
  end
end
