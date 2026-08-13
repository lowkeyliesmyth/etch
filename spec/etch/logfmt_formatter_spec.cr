require "../spec_helper"

# Test helper.
# Builds a formatter attached to the timestamp key-governing *time_format*.
private def logfmt_formatter(time_format : String = Etch::TimeFormat::DEFAULT) : Etch::LogfmtFormatter
  Etch::LogfmtFormatter.new(time_format)
end

describe Etch::LogfmtFormatter do
  describe "#render" do
    it "renders reserved keys in order, without bracketing the caller" do
      stamp = Time.local(2022, 1, 2, 3, 4, 5, location: Time::Location.fixed("here", -7 * 3600))
      kvs = [
        {Etch::TIMESTAMP_KEY, stamp},
        {Etch::LEVEL_KEY, Etch::Level::Error},
        {Etch::CALLER_KEY, "etch/logger.cr:42"},
        {Etch::PREFIX_KEY, "baking"},
        {Etch::MESSAGE_KEY, "cookies"},
      ] of Tuple(String, Etch::Value)
      logfmt_formatter.render(kvs).should eq(
        %(time="2022/01/02 03:04:05" level=error caller=etch/logger.cr:42 prefix=baking msg=cookies\n)
      )
    end

    it "formats a Time field as RFC3339-nano while leaving the timestamp key to use time_format" do
      stamp = Time.local(2022, 1, 2, 3, 4, 5, location: Time::Location.fixed("here", -7 * 3600))
      kvs = [{Etch::TIMESTAMP_KEY, stamp}, {"seen", stamp}] of Tuple(String, Etch::Value)
      logfmt_formatter.render(kvs).should eq(
        %(time="2022/01/02 03:04:05" seen=2022-01-02T03:04:05.000000000-07:00\n)
      )
    end

    it "writes bare safe values and quoted unsafe ones" do
      kvs = [
        {"empty", ""},
        {"eq", "a=b"},
        {"quote", %(say "hi")},
        {"err", Exception.new("foo: bar")},
      ] of Tuple(String, Etch::Value)
      logfmt_formatter.render(kvs).should eq(%(empty= eq="a=b" quote="say \\"hi\\"" err="foo: bar"\n))
    end

    it "discerns between a nil value and the literal string 'null'" do
      kvs = [{"nil", nil}, {"literal", "null"}] of Tuple(String, Etch::Value)
      logfmt_formatter.render(kvs).should eq(%(nil=null literal="null"\n))
    end

    it "renders scalar types raw and unmodified" do
      kvs = [{"b", true}, {"i", 42_i64}, {"f", 1.5}] of Tuple(String, Etch::Value)
      logfmt_formatter.render(kvs).should eq("b=true i=42 f=1.5\n")
    end

    it "escapes control characters when inside a quoted value" do
      kvs = [
        {"tab", "a\tb"},
        {"nl", "a\nb"},
        {"bell", "a\u{7}b"},
        {"del", "a\u{7f}b"},
      ] of Tuple(String, Etch::Value)
      logfmt_formatter.render(kvs).should eq(
        %(tab="a\\tb" nl="a\\nb" bell="a\\u0007b" del="a\\u007fb"\n)
      )
    end

    it "strips unsafe runes from a key and  successfully drops the pair if nothing survives" do
      kvs = [{"bad key", "v"}, {"=\"", "dropped"}, {"ok", "v"}] of Tuple(String, Etch::Value)
      logfmt_formatter.render(kvs).should eq("badkey=v ok=v\n")
    end

    it "renders an empty record as a bare newline" do
      logfmt_formatter.render(Etch::Fields.new).should eq("\n")
    end
  end
end
