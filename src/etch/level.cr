module Etch
  # Raised by `Level.parse` when given a string that calls an unknown level.
  class InvalidLevelError < Exception
  end

  # Severity levels ordered by increasing importance.
  #
  # `None` is an internal sentinel used by `print`, is never parsed, and is not a user-facing level
  enum Level : Int32
    Debug = -4
    Info  =  0
    Warn  =  4
    Error =  8
    Fatal = 12
    None  = Int32::MAX

    # Returns the lowercase level name to *io*.
    #
    # Internal `None` sentinel falls through to its integer value.
    def to_s(io : IO) : Nil
      case self
      in Debug then io << "debug"
      in Info  then io << "info"
      in Warn  then io << "warn"
      in Error then io << "error"
      in Fatal then io << "fatal"
      in None  then io << value
      end
    end

    # Returns the level named by case-insensitive *string*, or `nil` if the name doesn't match one of the Level enum names.
    def self.parse?(string : String) : Level?
      case string.downcase
      when "debug" then Debug
      when "info"  then Info
      when "warn"  then Warn
      when "error" then Error
      when "fatal" then Fatal
      end
    end

    # Returns the level named by case-insensitive *string*.
    #
    # Raises if *string* doesn't match one of the Level enum names.
    def self.parse(string : String) : Level
      parse?(string) || raise InvalidLevelError.new("invalid level: #{string.inspect}")
    end
  end
end
