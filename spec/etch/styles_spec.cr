require "../spec_helper"

# Force a profile so testing is deterministic and not dependent on the test runner's TTY
private def styled_renderer : Sheen::Renderer
  renderer = Sheen::Renderer.new(IO::Memory.new)
  renderer.color_profile = Foundation::Profile::ANSI256
  renderer
end

describe Etch::Styles do
  describe ".default" do
    it "renders styled level labels as expected" do
      r = styled_renderer
      levels = Etch::Styles.default.levels
      levels[Etch::Level::Debug].renderer(r).to_s.should eq("\e[1;38;5;63mDEBU\e[0m")
      levels[Etch::Level::Info].renderer(r).to_s.should eq("\e[1;38;5;86mINFO\e[0m")
      levels[Etch::Level::Warn].renderer(r).to_s.should eq("\e[1;38;5;192mWARN\e[0m")
      levels[Etch::Level::Error].renderer(r).to_s.should eq("\e[1;38;5;204mERRO\e[0m")
      levels[Etch::Level::Fatal].renderer(r).to_s.should eq("\e[1;38;5;161mFATA\e[0m")
    end

    it "explicitly doesn't have a style on the None sentinel, so no level label gets printed" do
      Etch::Styles.default.levels.has_key?(Etch::Level::None).should be_false
    end

    it "styles chrome and leaves the content plain" do
      r = styled_renderer
      styles = Etch::Styles.default
      styles.caller.renderer(r).render("etch/logger.cr:42").should eq("\e[2metch/logger.cr:42\e[0m")
      styles.prefix.renderer(r).render("baking:").should eq("\e[1;2mbaking:\e[0m")
      styles.key.renderer(r).render("err").should eq("\e[2merr\e[0m")
      styles.separator.renderer(r).render("=").should eq("\e[2m=\e[0m")
      styles.timestamp.renderer(r).render("13:04").should eq("13:04")
      styles.message.renderer(r).render("cookies").should eq("cookies")
      styles.value.renderer(r).render("burned").should eq("burned")
    end

    it "enters the world with no key or value overrides set" do
      styles = Etch::Styles.default
      styles.keys.should be_empty
      styles.values.should be_empty
    end
  end

  describe "#clone" do
    it "keeps the child level, key, and value maps independent of the parent" do
      original = Etch::Styles.default
      copy = original.clone
      copy.levels[Etch::Level::Error] = Sheen::Style.new.string("BOOM")
      copy.keys["err"] = Sheen::Style.new.bold
      copy.values["err"] = Sheen::Style.new.faint

      original.levels[Etch::Level::Error].value.should eq("ERROR")
      original.keys.should be_empty
      original.values.should be_empty
    end
  end

  describe "overrides" do
    it "modifies one level without pestering its siblings" do
      r = styled_renderer
      styles = Etch::Styles.default
      styles.levels[Etch::Level::Error] = Sheen::Style.new.string("ERR!!").bold
      styles.levels[Etch::Level::Error].renderer(r).to_s.should eq("\e[1mERR!!\e[0m")
      styles.levels[Etch::Level::Info].renderer(r).to_s.should eq("\e[1;38;5;86mINFO\e[0m")
    end
  end
end
