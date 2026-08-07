require "../spec_helper"

describe Etch::Escape do
  describe ".needs_quoting?" do
    it "leaves a bare token alone" do
      Etch::Escape.needs_quoting?("cookies").should be_false
      Etch::Escape.needs_quoting?("").should be_false
    end

    it "flags whitespace, separators, and quotes" do
      Etch::Escape.needs_quoting?("two words").should be_true
      Etch::Escape.needs_quoting?("k=v").should be_true
      Etch::Escape.needs_quoting?(%(say "hi")).should be_true
    end

    it "flags unprintable runes, including those that render as blanks" do
      Etch::Escape.needs_quoting?("line\nbreak").should be_true
      Etch::Escape.needs_quoting?("\e[1mansi\e[0m").should be_true
      Etch::Escape.needs_quoting?("zero\u200Bwidth").should be_true
      Etch::Escape.needs_quoting?("nbsp\u00A0here").should be_true
      Etch::Escape.needs_quoting?("bad\uFFFDbyte").should be_true
    end

    it "leaves printable non-ASCII alone" do
      Etch::Escape.needs_quoting?("猫咪").should be_false
      Etch::Escape.needs_quoting?("🍪").should be_false
    end
  end

  describe ".escape" do
    it "returns input unmodified when nothing needs to be escaped" do
      Etch::Escape.escape("plain text").should eq("plain text")
    end

    it "renders the named control escapes" do
      Etch::Escape.escape("line\nbreak\ttab\rreturn").should eq("line\\nbreak\\ttab\\rreturn")
    end

    it "renders low control bytes as `\\xNN`" do
      Etch::Escape.escape("\e[1mansi").should eq("\\x1b[1mansi")
    end

    it "renders DEL and wider unprintables as \\u" do
      Etch::Escape.escape("\u007F").should eq("\\u007f")
      Etch::Escape.escape("zero\u200Bwidth").should eq("zero\\u200bwidth")
    end

    it "renders astral unprintables as \\U" do
      Etch::Escape.escape("\u{1D173}").should eq("\\U0001d173")
    end

    it "escapes quotes only when asked" do
      Etch::Escape.escape(%(say "hi"), true).should eq(%(say \\"hi\\"))
      Etch::Escape.escape(%(say "hi"), false).should eq(%(say "hi"))
    end

    it "leaves printable non-ASCII alone" do
      Etch::Escape.escape("猫咪").should eq("猫咪")
    end
  end
end
