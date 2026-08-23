# Repository defaults and local policy files

This repository supplies GitHub's organization-wide community health defaults. A consumer
repository inherits those files only when it does not have a local file in a supported location;
a local file always takes precedence.

The `workflow-templates/` directory is also organization-wide, but only as a catalog in GitHub's
**New workflow** interface. Choosing a template copies a workflow into the consumer repository.
Workflows are never inherited or updated automatically from this repository.

## Files that are not inherited

GitHub does not inherit either of these files from an organization `.github` repository:

- `.github/CODEOWNERS`
- `.github/dependabot.yml`

They must exist in each consumer repository. ApiraTech distributes missing copies with an
activity-scoped codemod over Git and opens a pull request in each repository. The codemod skips
and reports every existing local copy; it does not overwrite repository-specific ownership or
dependency policy.

The default `CODEOWNERS` file owns only `.github/CODEOWNERS` and
`.github/dependabot.yml`. It does not claim product code, change repository permissions, or alter
branch settings. The default Dependabot file enables weekly GitHub Actions dependency updates; it
does not guess application package ecosystems. A repository can keep or introduce a more specific
local policy when its maintainers need different owners, package ecosystems, directories,
schedules, or grouping behavior.

## Practical consequence

Do not treat a file committed here as proof that a consumer received it. Verify community-health
inheritance in a named consumer, verify workflow templates through the New workflow interface,
and verify `CODEOWNERS` and Dependabot configuration in every repository where they are required.
