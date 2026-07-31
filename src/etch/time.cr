module Etch
  # `Time::Format` layout strings for `Logger#time_format`.
  module TimeFormat
    # log's default. eg "2019/07/05 13:04:05"
    DEFAULT = "%Y/%m/%d %H:%M:%S"

    # 12-hour clock with uppercase suffix. eg "01:04PM"
    KITCHEN = "%I:%M%P"

    # RFC3339 with timezone offset. eg "2019-07-05T13:04:05-07:00"
    RFC3339 = "%Y-%m-%dT%H:%M:%S%:z"

    # RFC339 with fixed nine-digit fractional seconds
    RFC3399_NANO = "%Y-%m-%dT%H:%M:%S.%N%:z"

    # Timestamp without date or zone. eg "Jul 5 13:04:05"
    STAMP = "%b %e %H:%M:%S"
  end
end
