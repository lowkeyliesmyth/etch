require "sheen"
require "./level"

module Etch
  # Styling for the `Text` formatter. Mutable and shared by unique name identity so a caller can adjust one field without rebuilding the whole set.
  class Styles
    property timestamp : Sheen::Style
    property caller : Sheen::Style
    property prefix : Sheen::Style
    property message : Sheen::Style
    property key : Sheen::Style
    property value : Sheen::Style
    property separator : Sheen::Style
    property levels : Hash(Level, Sheen::Style)
    property keys : Hash(String, Sheen::Style)
    property values : Hash(String, Sheen::Style)

    # Every field defaults to an unstyled `Sheen::Style` and an empty override map.
    def initialize(
      @timestamp : Sheen::Style = Sheen::Style.new,
      @caller : Sheen::Style = Sheen::Style.new,
      @prefix : Sheen::Style = Sheen::Style.new,
      @message : Sheen::Style = Sheen::Style.new,
      @key : Sheen::Style = Sheen::Style.new,
      @value : Sheen::Style = Sheen::Style.new,
      @separator : Sheen::Style = Sheen::Style.new,
      @levels : Hash(Level, Sheen::Style) = {} of Level => Sheen::Style,
      @keys : Hash(String, Sheen::Style) = {} of String => Sheen::Style,
      @values : Hash(String, Sheen::Style) = {} of String => Sheen::Style,
    )
    end

    # The default style. Duh. A pragmatic starting point that looks pretty cool I guess.
    def self.default : Styles
      new(
        caller: Sheen::Style.new.faint,
        prefix: Sheen::Style.new.bold.faint,
        key: Sheen::Style.new.faint,
        separator: Sheen::Style.new.faint,
        levels: {
          Level::Debug => level_style(Level::Debug.to_s.upcase, "#5f5fff"),
          Level::Info  => level_style(Level::Info.to_s.upcase, "#5fffd7"),
          Level::Warn  => level_style(Level::Warn.to_s.upcase, "#d7ff87"),
          Level::Error => level_style(Level::Error.to_s.upcase, "#ff5f87"),
          Level::Fatal => level_style(Level::Fatal.to_s.upcase, "#d7005f"),
        },
      )
    end

    # Build a bolded `Sheen::Style` for a *text* level tag, truncated to four columns with *color* applied.
    private def self.level_style(text : String, color : String) : Sheen::Style
      Sheen::Style.new.string(text).bold.max_width(4).foreground(Sheen.color(color))
    end

    # Creates an independent copy of the target `Styles`. The map fields are duped so the child can be re-styled and also stay independent.
    def clone : Styles
      Styles.new(
        timestamp: @timestamp,
        caller: @caller,
        prefix: @prefix,
        message: @message,
        key: @key,
        value: @value,
        separator: @separator,
        levels: @levels.dup,
        keys: @keys.dup,
        values: @values.dup,
      )
    end
  end
end
