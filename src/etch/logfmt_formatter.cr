require "./formatter"
require "./logfmt_encoder"
require "./record"

module Etch
  # Renders an encoded log record as a logfmt line.
  #
  # No styling is applied here because it’s logfmt. Callers are bare instead of bracketed. Styles are only applied to the Text formatter.
  struct LogfmtFormatter
    def initialize(@time_format : String)
    end

    # Renders *record* as one newline terminated logfmt record.
    def render(record : Record) : String
      String.build do |io|
        encoder = LogfmtEncoder.new(io)
        record.each do |item|
          case item
          in Record::Timestamp
            encoder.encode(TIMESTAMP_KEY, item.value.to_s(@time_format))
          in Record::Severity
            encoder.encode(LEVEL_KEY, item.value)
          in Record::Caller
            encoder.encode(CALLER_KEY, item.value)
          in Record::Prefix
            encoder.encode(PREFIX_KEY, item.value)
          in Record::Message
            encoder.encode(MESSAGE_KEY, item.value)
          in Record::Payload
            encoder.encode(item.key, item.value)
          end
        end
        encoder.end_record
      end
    end
  end
end
