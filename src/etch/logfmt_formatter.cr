require "./formatter"
require "./logfmt_encoder"
require "./value"

module Etch
  # Renders an encoded log record as a logfmt line.
  #
  # No styling is applied here because it’s logfmt. Callers are bare instead of bracketed. Styles are only applied to the Text formatter.
  struct LogfmtFormatter
    def initialize(@time_format : String)
    end

    # Renders *kvs* as one newline terminated logfmt record.
    def render(kvs : Fields) : String
      String.build do |io|
        encoder = LogfmtEncoder.new(io)
        kvs.each do |(key, value)|
          encoder.encode(key, coerce(key, value))
        end
        encoder.end_record
      end
    end

    # Runs only the record timestamp *key*-*value* pair through `time_format`, leaving other values unmodified.
    private def coerce(key : String, value : Value) : Value
      return value.to_s(@time_format) if key == TIMESTAMP_KEY && value.is_a?(Time)
      value
    end
  end
end
