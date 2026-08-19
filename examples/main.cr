require "./examples"

# CLI dispatcher for Etch reference consumer examples.as
#
# Usage: `crystal run examples/main.cr -- <example|all>`
name = ARGV[0]?

case name
when nil
  STDERR.puts "missing example name"
  STDERR.puts "usage: crystal run examples/main.cr -- <example|all>"
  STDERR.puts "available examples: #{Examples.names.join(", ")}"
  exit 1
when "all"
  original_default = Etch.default

  begin
    Examples.names.each do |ex_name|
      Etch.default = original_default
      STDOUT.puts "=== #{ex_name} ==="
      Examples.run(ex_name, STDOUT)
      STDOUT.puts
    end
  ensure
    Etch.default = original_default
  end
else
  begin
    Examples.run(name, STDOUT)
  rescue ex : Examples::UnknownExample
    STDERR.puts ex.message
    STDERR.puts "usage: crystal run examples/main.cr -- <example|all>"
    exit 1
  end
end
