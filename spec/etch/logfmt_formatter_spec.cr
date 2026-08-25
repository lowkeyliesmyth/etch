require "../spec_helper"

# Test helper.
# Builds a formatter attached to the timestamp key-governing *time_format*.
private def logfmt_formatter(time_format : String = Etch::TimeFormat::DEFAULT) : Etch::LogfmtFormatter
  Etch::LogfmtFormatter.new(time_format)
end

# Test record fixture helper
private def logfmt_record(
  level : Etch::Level = Etch::Level::None,
  msg = "",
  fields : Etch::Fields = Etch::Fields.new,
  timestamp : Time? = nil,
  *,
  report_timestamp : Bool = false,
  report_caller : Bool = false,
  file : String = "etch/logger.cr",
  line : Int32 = 42,
  prefix : String = "",
) : Etch::Record
  Etch::Record.new(
    level,
    msg,
    Etch::Fields.new,
    fields,
    timestamp,
    file,
    line,
    report_timestamp: report_timestamp,
    time_function: ->(time : Time) { time },
    report_caller: report_caller,
    caller_formatter: nil,
    prefix: prefix,
  )
end

describe Etch::LogfmtFormatter do
  describe "#render" do
    it "renders reserved keys in order, without bracketing the caller" do
      stamp = Time.local(2022, 1, 2, 3, 4, 5, location: Time::Location.fixed("here", -7 * 3600))
      record = logfmt_record(
        timestamp: stamp,
        report_timestamp: true,
        level: Etch::Level::Error,
        report_caller: true,
        prefix: "baking",
        msg: "cookies",
      )
      logfmt_formatter.render(record).should eq(
        %(time="2022/01/02 03:04:05" level=error caller=etch/logger.cr:42 prefix=baking msg=cookies\n)
      )
    end

    it "formats a Time field as RFC3339-nano while leaving the timestamp key to use time_format" do
      stamp = Time.local(2022, 1, 2, 3, 4, 5, location: Time::Location.fixed("here", -7 * 3600))
      record = logfmt_record(
        timestamp: stamp,
        report_timestamp: true,
        fields: [{"seen", stamp}],
      )
      logfmt_formatter.render(record).should eq(
        %(time="2022/01/02 03:04:05" seen=2022-01-02T03:04:05.000000000-07:00\n)
      )
    end

    it "writes bare safe values and quoted unsafe ones" do
      record = logfmt_record(
        fields: [
          {"empty", ""},
          {"eq", "a=b"},
          {"quote", %(say "hi")},
          {"err", Exception.new("foo: bar")},
        ]
      )
      logfmt_formatter.render(record).should eq(%(empty= eq="a=b" quote="say \\"hi\\"" err="foo: bar"\n))
    end

    it "discerns between a nil value and the literal string 'null'" do
      record = logfmt_record(
        fields: [{"nil", nil}, {"literal", "null"}]
      )
      logfmt_formatter.render(record).should eq(%(nil=null literal="null"\n))
    end

    it "renders scalar types raw and unmodified" do
      record = logfmt_record(
        fields: [{"b", true}, {"i", 42_i64}, {"f", 1.5}]
      )
      logfmt_formatter.render(record).should eq("b=true i=42 f=1.5\n")
    end

    it "escapes control characters when inside a quoted value" do
      record = logfmt_record(
        fields: [
          {"tab", "a\tb"},
          {"nl", "a\nb"},
          {"bell", "a\u{7}b"},
          {"del", "a\u{7f}b"},
        ]
      )
      logfmt_formatter.render(record).should eq(
        %(tab="a\\tb" nl="a\\nb" bell="a\\u0007b" del="a\\u007fb"\n)
      )
    end

    it "strips unsafe runes from a key and  successfully drops the pair if nothing survives" do
      record = logfmt_record(
        fields: [
          {"bad key", "v"},
          {"=\"", "dropped"},
          {"ok", "v"},
        ]
      )
      logfmt_formatter.render(record).should eq("badkey=v ok=v\n")
    end

    it "renders an empty record as a bare newline" do
      logfmt_formatter.render(logfmt_record).should eq("\n")
    end
  end
end
