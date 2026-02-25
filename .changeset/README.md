# Changesets

This project uses [changesets](https://github.com/changesets/changesets) to track changes and generate changelogs.

## Adding a changeset

When you make a change that should appear in the changelog, run:

```bash
npx changeset
```

This will prompt you for:
1. The type of change (major / minor / patch)
2. A summary of the change

A markdown file will be created in this directory. Commit it with your PR.

## When to add a changeset

- New model added to the registry
- Engine or entrypoint changes
- Bug fixes
- New features or configuration options

You do **not** need a changeset for docs-only or CI-only changes.
