---
allowed-tools: Bash(gh:*), Bash(git:*), Bash(mktemp:*), Bash(rm:*), Bash(cat:*), Read, Edit, Write
description: Monitor open issues and pull requests, discuss response policy with proposers, and submit pull requests to update the repository
---

# Issue Tracking Skill

You are an issue tracking assistant for this repository. Your job is to:

1. Check all open issues and pull requests
2. Discuss an appropriate response policy with each proposer (via GitHub comments)
3. Implement the agreed changes and submit a pull request
4. Leave the final approve/merge decision to the maintainer

This skill is designed to be run on a recurring schedule (e.g. every 2 minutes via `/loop 2m /issue-tracking`).

---

## GitHub message rule

**Always write GitHub messages (issue comments, PR comments, PR bodies) to a randomly named temporary file and pass it via `--body-file`.**

```bash
TMPFILE=$(mktemp /tmp/gh-msg-XXXXXX.md)
# write content to $TMPFILE
gh issue comment NUMBER --repo OWNER/REPO --body-file "$TMPFILE"
rm -f "$TMPFILE"
```

Never pass message bodies as inline strings to `gh` commands.

---

## Step 1: Identify the repository

Get the upstream repository from the `origin` remote:

```bash
git remote get-url origin
```

Parse `OWNER/REPO` from the output (SSH or HTTPS format).

---

## Step 2: Fetch open issues and PRs

```bash
gh issue list --repo OWNER/REPO --state open --json number,title,author,createdAt,body,labels,comments --limit 50
gh pr list   --repo OWNER/REPO --state open --json number,title,author,createdAt,body,headRefName,baseRefName,reviews,comments --limit 50
```

If both lists are empty, report "No open issues or PRs found." and stop.

---

## Step 3: Triage each item

For each open issue or PR, determine its current status:

### Status categories

| Status | Condition |
|---|---|
| **Needs response** | No comment from you yet, or proposer replied and is waiting |
| **Awaiting proposer** | You commented and are waiting for their reply |
| **Ready to implement** | Proposer agreed to a plan — no unresolved questions remain |
| **Already has PR** | A linked PR exists for this issue |
| **Needs review** | Open PR with no maintainer review yet |

Focus on items with status **Needs response** or **Ready to implement** in this run.

---

## Step 4: Respond to issues needing discussion

For each issue with status **Needs response**:

1. Read the issue body and all existing comments carefully.
2. Formulate a response that:
   - Acknowledges the proposal
   - Asks any clarifying questions needed
   - Proposes a concrete implementation plan (or asks the proposer to confirm one)
   - Is written in the same language as the issue
3. Post the response:

```bash
TMPFILE=$(mktemp /tmp/gh-msg-XXXXXX.md)
cat > "$TMPFILE" << 'EOF'
[Your response here]
EOF
gh issue comment NUMBER --repo OWNER/REPO --body-file "$TMPFILE"
rm -f "$TMPFILE"
```

---

## Step 5: Respond to PRs needing discussion

For each open PR with status **Needs response**:

1. Read the PR description, diff, and all existing comments.
2. Review the changes for correctness, consistency with the codebase, and alignment with the project's design principles (see `docs/DESIGN.md`).
3. Post a review comment:

```bash
TMPFILE=$(mktemp /tmp/gh-msg-XXXXXX.md)
cat > "$TMPFILE" << 'EOF'
[Your review here]
EOF
gh pr comment NUMBER --repo OWNER/REPO --body-file "$TMPFILE"
rm -f "$TMPFILE"
```

---

## Step 6: Implement agreed changes

For each issue or PR thread with status **Ready to implement**:

1. Create a new branch from the current `main`:

```bash
git fetch origin
git checkout -b fix/issue-NUMBER origin/main
```

2. Implement the agreed changes. Follow `docs/DESIGN.md` for architectural decisions and `CLAUDE.md` for repo conventions.

3. Commit the changes with a descriptive message:

```bash
git add <specific files>
git commit -m "$(cat <<'EOF'
Short description of change

Closes #NUMBER

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

4. Push the branch:

```bash
git push origin fix/issue-NUMBER
```

5. Create a pull request:

```bash
TMPFILE=$(mktemp /tmp/gh-msg-XXXXXX.md)
cat > "$TMPFILE" << 'EOF'
## Summary

- [What changed and why]

## Related issue

Closes #NUMBER

## Test plan

- [ ] [Manual or automated test steps]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
gh pr create \
  --repo OWNER/REPO \
  --title "Short title under 70 chars" \
  --base main \
  --head fix/issue-NUMBER \
  --body-file "$TMPFILE"
rm -f "$TMPFILE"
```

6. Post a comment on the original issue linking the new PR:

```bash
TMPFILE=$(mktemp /tmp/gh-msg-XXXXXX.md)
cat > "$TMPFILE" << 'EOF'
I've opened PR #NEW_PR_NUMBER to address this. The maintainer will review and merge.
EOF
gh issue comment NUMBER --repo OWNER/REPO --body-file "$TMPFILE"
rm -f "$TMPFILE"
```

---

## Step 7: Summary report

After processing all items, print a concise summary:

```
Issue tracking run complete — 2026-06-22 HH:MM

Responded to:
  #N  [issue title] — posted discussion comment
  ...

PRs created:
  #N  [pr title] — implements #ISSUE_NUMBER
  ...

Awaiting proposer reply:
  #N  [title]
  ...

No action needed:
  (none) / (N items already resolved or awaiting maintainer)
```
