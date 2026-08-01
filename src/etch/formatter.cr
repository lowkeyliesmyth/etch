module Etch
  # Output encodings for a `Logger`. Default `Text` is styled and human readable.
  # `JSON` and `Logfmt` are machine-readable and unstyled.
  enum Formatter
    Text
    JSON
    Logfmt
  end

  # Output key names.
  TIMESTAMP_KEY = "time"
  MESSAGE_KEY   = "msg"
  LEVEL_KEY     = "level"
  CALLER_KEY    = "caller"
  PREFIX_KEY    = "prefix"
end
