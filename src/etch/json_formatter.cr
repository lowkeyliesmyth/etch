require "json"
require "./formatter"
require "./level"
require "./time"
require "./value"

module Etch
  # Renders a log record as a single JSON object.
  #
  # No styling is applied here because it's JSON. Styles are only applied to the `Text` formatter.
  struct JSONFormatter
    # Fallback for a value that JSON just can't represent
    INVALID_VALUE = "invalid value"

    def initialize(@time_format : String)
    end

    # Renders *kvs* as one newline terminted JSON object.
    #
    # Duped keys are preserved in order.
    def render(kvs : Fields) : String
      String.build do |io|
        JSON.build(io) do |json|
          json.object do
            kvs.each { |(key, value)| write_pair(json, key, value) }
          end
        end
        io << '\n'
      end
    end

    # Writes one *key*-*value* pair to *json*. Reserved keys are mapped to their associated *JSON* structures.
    #
    # Note: A reserved *key* of the wrong value type is skipped.
    private def write_pair(json : JSON::Builder, key : String, value : Value) : Nil
      case key
      when TIMESTAMP_KEY
        return unless time = value.as?(Time)
        json.field(key, time.to_s(@time_format))
      when LEVEL_KEY
        return unless level = value.as?(Level)
        json.field(key, level.to_s)
      when CALLER_KEY, PREFIX_KEY
        return unless text = value.as?(String)
        json.field(key, text)
      when MESSAGE_KEY
        return if value.nil?
        json.field(key, value.to_s)
      else
        json.field(key) { write_value(json, value) }
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
