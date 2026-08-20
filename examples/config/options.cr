require "../examples"

module Examples::Config::Options
  # Consumer exhibiting constructor options
  def self.run(io : IO) : Nil
    logger = Etch::Logger.new(
      io,
      prefix: "Baking cookies",
      time_format: Etch::TimeFormat::KITCHEN,
      report_timestamp: true,
      report_caller: true,
    )

    logger.info "Starting oven!", degree: 375, kind: "Fahrenheit"
    logger.info "Mixing ingredients!", tool: "bowl"
    logger.info "Placing cookies!", tool: "sheet"
    logger.info "Finished baking!"
  end
end

Examples.register("config/options") do |io|
  Examples::Config::Options.run(io)
end
