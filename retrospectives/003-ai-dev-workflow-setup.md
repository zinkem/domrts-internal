# Retrospective: AI-Assisted Development Workflow Setup

**Date:** December 10, 2025
**Session Focus:** Establishing conventions, templates, and workflows for AI-assisted development

---

## Overview

This session focused on setting up infrastructure to make AI-assisted development more effective. The core insight driving the work: **AI assistants need context to be useful, and that context should be injected automatically rather than manually provided each time.**

We built a system of git hooks, templates, and GitHub integrations that:
1. Automatically provide relevant context during commits
2. Keep the AI informed about recent changes and priorities
3. Standardize issue tracking and PR workflows
4. Create a rich commit history that serves as documentation

---

## What We Built

### 1. Commit Message Template (`.gitmessage`)

A structured template that prompts for:
- Type prefix (feat, fix, refactor, perf, docs, test, chore)
- Bug risk assessment
- Affected modules checklist
- Testing confirmation

**Why it matters:** Commit messages become a searchable log of what changed, why, and what might break. Future AI sessions can scan `git log` to understand recent risky areas.

### 2. Git Hooks (`.githooks/`)

Three hooks that inject context at key moments:

| Hook | Trigger | What it does |
|------|---------|--------------|
| `prepare-commit-msg` | Before editing commit message | Injects template + full staged diff |
| `post-commit` | After commit completes | Shows workplan priorities as reminder |
| `post-checkout` | After switching branches | Shows recent commits + workplan |

**The key insight:** The `prepare-commit-msg` hook solves the "AI needs to see the diff" problem. By injecting the diff directly into the commit message file (as comments that get stripped), the AI automatically has full context when writing commit messages.

### 3. GitHub Issue Templates (`.github/ISSUE_TEMPLATE/`)

Three templates for different issue types:
- **Bug Report** - reproduction steps, expected/actual behavior, module checklist
- **Feature Request** - use case, proposed solution, complexity estimate
- **Performance Issue** - ties into workplan.txt, measurements, severity

### 4. PR Template (`.github/PULL_REQUEST_TEMPLATE.md`)

Standardized PR format with:
- Summary bullets
- Related issues (for auto-closing)
- Modules affected
- Bug risk assessment
- Testing checklist

### 5. CLAUDE.md

AI context file with:
- Project architecture overview
- Module responsibilities and complexity ratings
- Common patterns (state machines, coordinates, etc.)
- Performance hotspots reference
- Testing checklist

---

## The Workflow We Established

```
GitHub Issues
     │
     ▼
┌─────────────────────────────────────────────────┐
│  1. gh issue list --label showstopping          │
│  2. Pick issue, create branch:                  │
│     git checkout -b bugfix/123-desc develop     │
│     (post-checkout hook shows context)          │
└─────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────┐
│  3. Work on the fix                             │
│  4. Stage changes: git add <files>              │
│  5. Commit (no -m flag): git commit             │
│     (prepare-commit-msg injects diff)           │
│  6. AI reads .git/COMMIT_EDITMSG                │
│  7. AI writes informed commit message           │
│     (post-commit shows workplan reminder)       │
└─────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────┐
│  8. Push: git push -u origin HEAD               │
│  9. Create PR: gh pr create --base develop      │
│ 10. Merge: gh pr merge --merge --delete-branch  │
│ 11. Close issue if not auto-closed              │
│ 12. Sync: git checkout develop && git pull      │
└─────────────────────────────────────────────────┘
```

---

## Key Decisions Made

### Branch Strategy
- `stable` - releases cut from here
- `develop` - PRs merge here (the "hot" branch)
- `feature/`, `bugfix/`, `release/` - work branches

### Labels
- `feature` - new functionality
- `bugfix` - something broken
- `showstopping` - critical, blocks release
- `tablestakes` - must-have core functionality

### Commit Message Convention
```
<type>: <subject under 50 chars>

<body explaining what and why>

Bug Risk: low/medium/high
Areas to watch: <specific concerns>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

---

## Test Run: Issue #1

We validated the workflow end-to-end:

1. **Created issue #1:** "Update workplan.txt to mark completed items"
2. **Created branch:** `bugfix/1-update-workplan-completed-items`
3. **Made the fix:** Marked items #1 and #2 as ✅ DONE with commit references
4. **Committed:** With "Fixes #1" in the body
5. **Created PR #2:** Targeting develop
6. **Merged:** Via `gh pr merge --merge --delete-branch`
7. **Closed issue:** Manually (auto-close didn't trigger from commit body)

---

## Lessons Learned

### What Worked Well
- **Diff injection via prepare-commit-msg** - Elegant solution to the context problem
- **Workplan reminders in post-commit** - Keeps priorities visible without manual checking
- **gh CLI** - Much simpler than raw GitHub API for issue/PR management
- **Tracked hooks in .githooks/** - Survives cloning (with one config command)

### Gotchas Encountered
- `git commit -m "message"` bypasses the prepare-commit-msg template injection - must use `git commit` without `-m`
- "Fixes #N" in commit body doesn't always auto-close issues - may need manual close
- Remote branch must exist before creating PR targeting it

### Future Improvements to Consider
- Add a `pre-push` hook to run tests before pushing
- Consider GitHub Actions for CI/CD
- Maybe a hook or script to auto-create branch from issue number
- Could add issue templates for "tech debt" and "documentation"

---

## Files Created/Modified

| File | Purpose |
|------|---------|
| `.gitmessage` | Commit template |
| `.githooks/prepare-commit-msg` | Injects diff into commit message |
| `.githooks/post-commit` | Workplan reminder after commits |
| `.githooks/post-checkout` | Context on branch switch |
| `.githooks/README.md` | Instructions for enabling hooks |
| `.github/ISSUE_TEMPLATE/bug_report.md` | Bug report template |
| `.github/ISSUE_TEMPLATE/feature_request.md` | Feature request template |
| `.github/ISSUE_TEMPLATE/performance.md` | Performance issue template |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR template |
| `CLAUDE.md` | AI context file |
| `workplan.txt` | Now tracked in git |

---

## Summary

This session transformed the repository from "just code" into a structured development environment optimized for AI assistance. The key innovation is **automatic context injection** - rather than relying on the AI to remember to check things, the system surfaces relevant information at the right moments.

The workflow is lightweight (no complex tooling beyond git and gh CLI) but provides significant benefits:
- Consistent commit messages with risk assessment
- Automatic diff review before every commit
- Continuous visibility into project priorities
- Standardized issue and PR formats
- Rich git history that serves as documentation

Total time: ~1 hour to set up a workflow that will save many hours in future sessions.
