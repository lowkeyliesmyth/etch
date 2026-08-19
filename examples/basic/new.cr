require "../examples"

module Examples::Basic::New
  # An explicit logger with a structured field.
  def self.run(io : IO) : Nil
    logger = Etch::Logger.new(io)
    logger.warn "crunchy!", peanut_butter: true
  end
end

Examples.register("basic/new") do |io|
  Examples::Basic::New.run(io)
end
