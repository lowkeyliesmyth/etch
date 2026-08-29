## v0.1.0 (2026-08-29)

### Feat

- **examples**: add executable structured client consumer examples of etch (#6)
- **backend**: add stdlib log backend adapter with exposed config setters (#5)
- **default**: add top-level module level default logger and fiber level override (#4)
- **api**: add status helper for fatal error handling
- **json+logfmt**: add json and logfmt formatting support (#3)
- **textformatter**: implement text rendering with caller, quoting, and escaping support (#2)
- **styles**: add default style profile integrated into logger rendering (#1)
- **logger**: overload existing methods to allow accepting fields from runtime-keyed Enumerable types
- **logger**: allow callers to provide optional timestamp for backdated log entries and applying formatting
- **logger**: build out core log methods and render pipeline
- **logger**: add a mutable etch::logger with options config and caller formatters
- **time**: add timeformat module containing standard time layout strings
- **formatter**: add formatter enum defining encoding output key options
- **level**: add log level enum with a few parsing methods

### Bug Fixes

- **level**: add to_s overload and specs to ensure level output is always downcased

### Refactor

- **logger**: consolidate semantic config in options (#8)
- **logger**: logger and formatters defer to record for consistent structure (#7)
- remove unused and unnecessary caller_offset property
- **time**: fix references to rfc3339
- **init**: initial commit

### Build System

- **taskfile**: add zizmor gha static analysis shortcuts
- **all**: more linter, dependency, and project tooling setup

### CI

- **gha**: use crystal 1.21.0 in all workflows, fix releaes tagging
- **cz**: align versioning string on shards requirements
- **gha**: add standard spec, test, coverage gha workflows with codecov config
