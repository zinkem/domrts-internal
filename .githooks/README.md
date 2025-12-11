# Git Hooks

Custom hooks for AI-assisted development workflow.

## Enable Hooks

Run this once after cloning:

```bash
git config core.hooksPath .githooks
```

## Hooks

| Hook | When | What it does |
|------|------|--------------|
| prepare-commit-msg | Before editing commit message | Injects template + staged diff for AI context |
| post-commit | After commit completes | Shows confirmation + workplan reminders |
| post-checkout | After branch switch | Shows recent commits + workplan priorities |

## Commit Workflow

Use `git commit` without the `-m` flag so the prepare-commit-msg hook can inject the diff:

```bash
git add <files>
git commit          # Opens editor with template + diff
```

The AI can then read `.git/COMMIT_EDITMSG` to see the full diff in context.
