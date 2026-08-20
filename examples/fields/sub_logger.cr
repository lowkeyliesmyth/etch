require "../examples"

module Examples::Fields::SubLogger
  # Exercises inherited field accumulation and prefixed sub loggers.
  def self.run(io : IO) : Nil
    logger = Etch::Logger.new(io, level: :debug)
    batch = logger.with(batch: 2)
    batch.debug "Preparing batch 2..."

    chocolate_chips = batch
      .with(chocolate_chips: true)
      .with_prefix("baking")

    chocolate_chips.debug "Adding chocolate chips"
  end
end

Examples.register("fields/sub_logger") do |io|
  Examples::Fields::SubLogger.run(io)
end
