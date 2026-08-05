module Etch
  # Output encodings for a `Logger`. Default `Text` is styled and human readable.
  # `JSON` and `Logfmt` are machine-readable and unstyled.
  enum Formatter
    Text
    JSON
    Logfmt
  end

  # Timestamp field semantic tag that identifies the special, ordered fields in the k-v Fields array. The Logger rendering engine matches on these Fields tags to decide ordering and styling.
  TIMESTAMP_KEY = "time"
  # Message field semantic tag that identifies the special, ordered fields in the k-v Fields array. The Logger rendering engine matches on these Fields tags to decide ordering and styling.
  MESSAGE_KEY = "msg"
  # Level field semantic tag that identifies the special, ordered fields in the k-v Fields array. The Logger rendering engine matches on these Fields tags to decide ordering and styling.
  LEVEL_KEY = "level"
  # Caller field semantic tag that identifies the special, ordered fields in the k-v Fields array. The Logger rendering engine matches on these Fields tags to decide ordering and styling.
  CALLER_KEY = "caller"
  # Prefix field semantic tag that identifies the special, ordered fields in the k-v Fields array. The Logger rendering engine matches on these Fields tags to decide ordering and styling.
  PREFIX_KEY = "prefix"
end
