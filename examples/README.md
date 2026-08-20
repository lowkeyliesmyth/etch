# Etch Examples

Reference consumers of Etch that double as end-to-end demonstrations. Run one and watch the ~spice~ logs flow.

## Running

Using the taskfile helper:
``` bash
task example              # list registered examples
task example -- <name>    # run one example
task examples             # run every example
task examples:check       # type-check the examples without running
```

## Adding an example consumer

1. Create a new `examples/<group>/<name>.cr` exposing
   `Examples::<Group>::<Name>.run(io : IO)`.
2. Self-register the consumer at the end of the file:
```crystal
Examples.register("<group>/<name>") do |io|
    Examples::<Group>::<Name>.run(io)
end
```
3. Add `require "./<group>/<name>"` to `examples/examples.cr`.
4. Run `task examples:check` and `task example -- <group>/<name>` to verify
