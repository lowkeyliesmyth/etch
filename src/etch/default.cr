require "./logger"

# Fiber-local storage backing the `Etch.with_logger` override state.
# nil means no override is in effect and the package default logger is being used.
class Fiber
  # :nodoc:
  property etch_logger : Etch::Logger?
end

module Etch
  @@default_logger : Logger?
  @@default_mutex = Sync::Mutex.new

  # Returns the package default lazily constructed logger instance, with timestamp event reporting explicitly enabled.
  #
  # The same logger is returned until it's replaced via `Etch.default=`.
  def self.default : Logger
    @@default_mutex.synchronize do
      @@default_logger ||= Logger.new(report_timestamp: true)
    end
  end

  # Replaces the package default logger with *logger* and returns it.
  def self.default=(logger : Logger) : Logger
    @@default_mutex.synchronize do
      @@default_logger = logger
    end
  end

  # Returns the current fiber's logger override, falling back to `Etch.default` if unset.
  def self.current_logger : Logger
    Fiber.current.etch_logger || default
  end

  # Convenience alias for `Etch.current_logger`, which returns the current logger from the target fiber.
  def self.from_fiber : Logger
    current_logger
  end

  # Uses *logger* as the current fiber's logger for processing *block*.
  #
  # Returns the block's value and restores to the previous logger even if the block raises.
  #
  # The override is fiber local and does not propagate into child fibers spawned in the block. Unless overridden, those will use `Etch.default`.
  def self.with_logger(logger : Logger, &)
    previous = Fiber.current.etch_logger
    Fiber.current.etch_logger = logger
    begin
      yield
    ensure
      Fiber.current.etch_logger = previous
    end
  end
end
