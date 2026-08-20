require "../examples"

module Examples::Styles::Custom
  # Exhibits custom level, key, and value styles.
  def self.run(io : IO) : Nil
    styles = Etch::Styles.default
    styles.levels[Etch::Level::Error] = Sheen::Style.new
      .string("ERROR!!")
      .padding(0, 1)
      .background(Sheen.color("#ff5f5f"))
      .foreground(Sheen.color("#000000"))
    styles.keys["err"] = Sheen::Style.new.foreground(Sheen.color("#ff5f5f"))
    styles.values["err"] = Sheen::Style.new.bold

    logger = Etch::Logger.new(io, styles: styles)
    logger.error "This is fine", err: "kitchen on fire"
  end
end

Examples.register("styles/custom") do |io|
  Examples::Styles::Custom.run(io)
end
