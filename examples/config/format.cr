require "../examples"

module Examples::Config::Format
  # Consumer exhibiting sprintf-style formatting over a short loop.
  def self.run(io : IO) : Nil
    logger = Etch::Logger.new(io, report_timestamp: true, time_format: Etch::TimeFormat::RFC3339)

    1.upto(3) do |item|
      logger.infof "Baking %d / 3 ...", item
    end
  end
end

Examples.register("config/format") do |io|
  Examples::Config::Format.run(io)
end
