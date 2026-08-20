require "../examples"

module Examples::Formatters::Trio
  # Renders the same structured record with each available public formatter.
  def self.run(io : IO) : Nil
    Etch::Formatter.values.each do |fmtr|
      logger = Etch::Logger.new(io, formatter: fmtr)
      logger.info "Baking cookies", batch: 2
    end
  end
end

Examples.register("formatters/trio") do |io|
  Examples::Formatters::Trio.run(io)
end
