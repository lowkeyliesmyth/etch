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

  # Generate package-level mirrors for every logger level method and invocation.
  {% for name, return_type in {
                                debug: "Nil",
                                info:  "Nil",
                                warn:  "Nil",
                                error: "Nil",
                                fatal: "NoReturn",
                                print: "Nil",
                              } %}

  # Emits *msg* through the current logger with the provided *kv* fields.
  def self.{{ name.id }}(msg, __file : String = __FILE__, __line : Int32 = __LINE__, **kv) : {{ return_type.id }}
    current_logger.{{ name.id }}(msg, **kv, __file: __file, __line: __line)
  end


  # Emits *msg* through the current logger with runtime keyed *fields*.
  def self.{{ name.id }}(msg, fields : Enumerable(Tuple(String, V)), __file : String = __FILE__, __line : Int32 = __LINE__ ) : {{ return_type.id }} forall V
    current_logger.{{ name.id }}(msg, fields, __file: __file, __line: __line)
  end

  # Emits the *block* through the current logger with the given *kv* fields.
  def self.{{ name.id }}(__file : String = __FILE__, __line : Int32 = __LINE__, **kv, &) : {{ return_type.id }}
    current_logger.{{ name.id }}(**kv, __file: __file, __line: __line) { yield }
  end

  # Emits specifically formatted `sprintf(format, *args)` through the current logger.
  def self.{{ name.id }}f(format : String, *args, __file : String = __FILE__, __line : Int32 = __LINE__) : Nil
    current_logger.{{ name.id }}f(format, *args, __file: __file, __line: __line)
  end
  {% end %}

  # Emits *msg* at *level* through the current logger with the given *kv* fields.
  def self.log(level : Level, msg, __file : String = __FILE__, __line : Int32 = __LINE__, **kv) : Nil
    current_logger.log(level, msg, **kv, __file: __file, __line: __line)
  end

  # Emits *msg* at *level* through the current logger with runtime keyed *fields*.
  def self.log(level : Level, msg, fields : Enumerable(Tuple(String, V)), __file : String = __FILE__, __line : Int32 = __LINE__) : Nil forall V
    current_logger.log(level, msg, fields, __file: __file, __line: __line)
  end

  # Emits specifically formatted `sprintf(format, *args)` at *level* through the current logger.
  def self.logf(level : Level, format : String, *args, __file : String = __FILE__, __line : Int32 = __LINE__) : Nil
    current_logger.logf(level, format, *args, __file: __file, __line: __line)
  end

  # Returns an independent child of the current loggger with the given *kv* fields appended.
  def self.with(**kv) : Logger
    current_logger.with(**kv)
  end

  # Returns an independent child of the current logger with runtime keyed *fields* appended.
  def self.with(fields : Enumerable(Tuple(String, V))) : Logger forall V
    current_logger.with(fields)
  end

  # Returns an independent child of the current logger with *prefix* applied.
  def self.with_prefix(prefix : String) : Logger
    current_logger.with_prefix(prefix)
  end

  # Generate package-level config setters routed through the current logger.
  {% for name, type in {
                         level:            "Level",
                         prefix:           "String",
                         formatter:        "Formatter",
                         report_timestamp: "Bool",
                         report_caller:    "Bool",
                         time_format:      "String",
                         time_function:    "TimeFunction",
                         output:           "IO",
                         styles:           "Styles",
                       } %}
    # Sets `{{ name.id }}` on the current logger and returns *value*.`
    def self.{{ name.id }}=(value : {{ type.id }}) : {{ type.id }}
      current_logger.{{ name.id }} = value
    end
  {% end %}
end
