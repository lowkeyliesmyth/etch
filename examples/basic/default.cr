require "../examples"

module Examples::Basic::Default
  # Demonstrates the simple case, a package-level logging through the current default logger.
  def self.run(io : IO) : Nil
    Etch.with_logger(Etch::Logger.new(io)) do
      Etch.info "Hello world!"
      Etch.error "Oops!", err: "kitchen on fire"
    end
  end
end

Examples.register("basic/default") do |io|
  Examples::Basic::Default.run(io)
end
