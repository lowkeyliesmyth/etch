require "../examples"

module Examples::Fields::Error
  # Exercises an Exception used directly as a structured field value.
  def self.run(io : IO) : Nil
    logger = Etch::Logger.new(io)
    error = Exception.new("too much butter")

    logger.error "Failed to bake cookies", error: error
  end
end

Examples.register("fields/error") do |io|
  Examples::Fields::Error.run(io)
end
