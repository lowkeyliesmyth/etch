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

describe Etch::TextFormatter do
  describe "#render" do
    it "renders metadata chrome in order and terminates the line" do
      kvs = [
        {Etch::LEVEL_KEY, Etch::Level::Info},
        {Etch::CALLER_KEY, "etch/logger.cr:42"},
        {Etch::PREFIX_KEY, "baking"},
        {Etch::MESSAGE_KEY, "cookies"},
        {"batch", 2_i64},
      ] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq("INFO <etch/logger.cr:42> baking: cookies batch=2\n")
    end

    it "formats the timestamp through the given time format" do
      kvs = [
        {Etch::TIMESTAMP_KEY, Time.local(2022, 1, 2, 3, 4, 5)},
        {Etch::MESSAGE_KEY, "cookies"},
      ] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq("2022/01/02 03:04:05 cookies\n")
    end

    it "quotes a value containing spaces" do
      kvs = [{"err", "kitchen on fire"}] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq(%(err="kitchen on fire"\n))
    end

    it "successfully quotes a value that contains the separator character" do
      kvs = [{"expr", "a=b"}] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq(%(expr="a=b"\n))
    end

    it "quotes and escapes an embedded quote" do
      kvs = [{"say", %(he said "hi")}] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq(%(say="he said \\"hi\\""\n))
    end

    it "quotes and escapes a value carrying ANSI escape sequences" do
      kvs = [{"ansi", "\e[1mred\e[0m"}] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq(%(ansi="\\x1b[1mred\\x1b[0m"\n))
    end

    it "escapes a control character inside a quoted value" do
      kvs = [{"raw", "a\tb"}] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq(%(raw="a\\tb"\n))
    end

    it "renders nil as <nil> and an empty string as an empty quoted pair" do
      kvs = [{"a", nil}, {"b", ""}] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq(%(a=<nil> b=""\n))
    end

    it "indents a multiline value under its own key" do
      kvs = [
        {Etch::MESSAGE_KEY, "trace"},
        {"body", "line one\nline two"},
      ] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq("trace\n  body=\n  │ line one\n  │ line two\n")
    end

    it "skips a field carrying an empty key" do
      kvs = [
        {Etch::MESSAGE_KEY, "hi"},
        {"", "orphan"},
      ] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq("hi\n")
    end

    it "skips a reserved key carrying the wrong value type" do
      kvs = [
        {Etch::TIMESTAMP_KEY, "not a time"},
        {Etch::MESSAGE_KEY, "still here though"},
      ] of Tuple(String, Etch::Value)
      formatter.render(kvs).should eq("still here though\n")
    end

    it "renders no label for a level not registered in the styles" do
      styles = Etch::Styles.default
      styles.levels.delete(Etch::Level::Info)
      kvs = [
        {Etch::LEVEL_KEY, Etch::Level::Info},
        {Etch::MESSAGE_KEY, "quiet"},
      ] of Tuple(String, Etch::Value)
      formatter(styles: styles).render(kvs).should eq("quiet\n")

      kvs2 = [
        {Etch::LEVEL_KEY, "Foo"},
        {Etch::MESSAGE_KEY, "quiet"},
      ] of Tuple(String, Etch::Value)
      formatter(styles: styles).render(kvs2).should eq("quiet\n")
    end

    it "styles the level label at a color capable profile" do
      kvs = [
        {Etch::LEVEL_KEY, Etch::Level::Error},
        {Etch::MESSAGE_KEY, "boom"},
      ] of Tuple(String, Etch::Value)
      formatter(profile: Foundation::Profile::ANSI256).render(kvs)
        .should eq("\e[1;38;5;204mERRO\e[0m boom\n")
    end

    it "applies per-key and per-value styles overrides together" do
      styles = Etch::Styles.default
      styles.keys["err"] = Sheen::Style.new.bold
      styles.values["err"] = Sheen::Style.new.italic
      kvs = [{"err", "boom"}] of Tuple(String, Etch::Value)
      formatter(profile: Foundation::Profile::ANSI256, styles: styles).render(kvs)
        .should eq("\e[1merr\e[0m\e[2m=\e[0m\e[3mboom\e[0m\n")
    end

    it "consistently applies per-value style overrides across all of a multiline value" do
      styles = Etch::Styles.default
      styles.values["body"] = Sheen::Style.new.italic
      kvs = [{"body", "line one\nline two"}] of Tuple(String, Etch::Value)
      rendered = formatter(profile: Foundation::Profile::ANSI256, styles: styles).render(kvs)
      rendered.should contain("\e[3mline one\e[0m")
      rendered.should contain("\e[3mline two\e[0m")
    end
  end
end
