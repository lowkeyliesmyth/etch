require "../spec_helper"

# Test helper.
# Builds a formatter on a forced profile so output doesn't depend on runner TTY.
private def formatter(
  profile : Foundation::Profile = Foundation::Profile::NoTTY,
  styles : Etch::Styles = Etch::Styles.default,
  time_format : String = Etch::TimeFormat::DEFAULT,
) : Etch::TextFormatter
  renderer = Sheen::Renderer.new(IO::Memory.new)
  renderer.color_profile = profile
  Etch::TextFormatter.new(styles, renderer, time_format)
end

# Test record fixture helper
private def text_record(
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

describe Etch::TextFormatter do
  describe "#render" do
    it "renders metadata chrome in order and terminates the line" do
      record = text_record(
        level: Etch::Level::Info,
        msg: "cookies",
        prefix: "baking",
        report_caller: true,
        fields: [{"batch", 2_i64.as(Etch::Value)}],
      )
      formatter.render(record).should eq("INFO <etch/logger.cr:42> baking: cookies batch=2\n")
    end

    it "formats the timestamp through the given time format" do
      record = text_record(
        msg: "cookies",
        timestamp: Time.local(2022, 1, 2, 3, 4, 5),
        report_timestamp: true
      )
      formatter.render(record).should eq("2022/01/02 03:04:05 cookies\n")
    end

    it "quotes a value containing spaces" do
      record = text_record(fields: [{"err", "kitchen on fire"}])
      formatter.render(record).should eq(%(err="kitchen on fire"\n))
    end

    it "successfully quotes a value that contains the separator character" do
      record = text_record(fields: [{"expr", "a=b"}])
      formatter.render(record).should eq(%(expr="a=b"\n))
    end

    it "quotes and escapes an embedded quote" do
      record = text_record(fields: [{"say", %(he said "hi")}])
      formatter.render(record).should eq(%(say="he said \\"hi\\""\n))
    end

    it "quotes and escapes a value carrying ANSI escape sequences" do
      record = text_record(fields: [{"ansi", "\e[1mred\e[0m"}])
      formatter.render(record).should eq(%(ansi="\\x1b[1mred\\x1b[0m"\n))
    end

    it "escapes a control character inside a quoted value" do
      record = text_record(fields: [{"raw", "a\tb"}])
      formatter.render(record).should eq(%(raw="a\\tb"\n))
    end

    it "renders nil as <nil> and an empty string as an empty quoted pair" do
      record = text_record(fields: [{"a", nil}, {"b", ""}])
      formatter.render(record).should eq(%(a=<nil> b=""\n))
    end

    it "indents a multiline value under its own key" do
      record = text_record(
        msg: "trace",
        fields: [{"body", "line one\nline two"}]
      )
      formatter.render(record).should eq("trace\n  body=\n  │ line one\n  │ line two\n")
    end

    it "skips a field carrying an empty key" do
      record = text_record(
        msg: "hi",
        fields: [{"", "orphan"}]
      )
      formatter.render(record).should eq("hi\n")
    end

    it "renders no label for a level not registered in the styles" do
      styles = Etch::Styles.default
      styles.levels.delete(Etch::Level::Info)
      record = text_record(
        level: Etch::Level::Info,
        msg: "quiet",
      )
      formatter(styles: styles).render(record).should eq("quiet\n")
    end

    it "styles the level label at a color capable profile" do
      record = text_record(
        level: Etch::Level::Error,
        msg: "boom",
      )
      formatter(profile: Foundation::Profile::ANSI256).render(record)
        .should eq("\e[1;38;5;204mERRO\e[0m boom\n")
    end

    it "applies per-key and per-value styles overrides together" do
      styles = Etch::Styles.default
      styles.keys["err"] = Sheen::Style.new.bold
      styles.values["err"] = Sheen::Style.new.italic
      record = text_record(fields: [{"err", "boom"}])
      formatter(profile: Foundation::Profile::ANSI256, styles: styles).render(record)
        .should eq("\e[1merr\e[0m\e[2m=\e[0m\e[3mboom\e[0m\n")
    end

    it "consistently applies per-value style overrides across all of a multiline value" do
      styles = Etch::Styles.default
      styles.values["body"] = Sheen::Style.new.italic
      record = text_record(fields: [{"body", "line one\nline two"}])
      rendered = formatter(profile: Foundation::Profile::ANSI256, styles: styles).render(record)
      rendered.should contain("\e[3mline one\e[0m")
      rendered.should contain("\e[3mline two\e[0m")
    end
  end
end
