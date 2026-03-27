---
name: session-lesson-learned
description: Generate a lesson-learned document from the current session. Analyzes conversation context to extract what happened, what was expected, root cause, and the actionable lesson — then writes a structured markdown file using a standard template. Use this skill whenever the user wants to capture a learning, write a lesson learned, document what went wrong (or right), or preserve a session insight for future reference.
user-invocable: true
---

# Session Lesson Learned

Generate a lesson-learned document by analyzing the current conversation session.

## How It Works

This skill extracts insights from the conversation — the goal, what was expected, what actually happened, why, and what to do differently — then fills in a structured template and saves it as a markdown file.

## Steps

### 1. Analyze the Session

Scan the conversation to identify:

- **The goal** — what the user was trying to accomplish
- **The expectation** — what was assumed would work
- **The actual outcome** — what happened instead (or what was discovered)
- **The root cause** — why the gap exists (this is the most important part — not what happened, but WHY)
- **The lesson** — the actionable rule or design principle that follows
- **External references** — any URLs, articles, or docs that informed the learning
- **Tags** — derive from the domain (e.g., kubernetes, claude-code, gitops, azure, cicd)

### 2. Draft the Document

Read the template at `templates/lessons-learned-template.md` (relative to this skill's directory).

Fill in every section. Key quality criteria:

- **TL;DR** should deliver 80% of the value in 1-2 sentences
- **Context** should be 2-4 sentences max — just enough to understand the situation
- **Expected vs Actual** table should include concrete details, data, or numbers where available
- **Root Cause** must explain WHY, not just restate what happened. This is the most valuable section — spend time on it
- **The Lesson** should be stated as an imperative rule that someone can act on without reading the full doc
- **What to do instead / What NOT to do** should be specific enough to follow without ambiguity
- **Impact on Our Design** should list concrete changes (checkboxes) — things already done or still to do
- **References** should include any URLs discussed in the session

Set `date` to today's date. Set `audience` to `[personal, team]` unless the user specifies otherwise. Set `status` to `active`.

### 3. Present for Review

Show the full drafted document to the user and ask for confirmation before writing the file.

### 4. Save the File

**Default location:** Save to the current workspace directory (the working directory where Claude Code was launched).

If the user specifies a different path, use that instead.

**Filename convention:** `lesson-learned-<short-slug>.md` where `<short-slug>` is a kebab-case summary (3-5 words max).

Examples:
- `lesson-learned-preloaded-skills-ignored.md`
- `lesson-learned-envsubst-windows-path.md`
- `lesson-learned-argocd-finalizer-cascade.md`

### 5. Suggest Memory Update (Optional)

If the lesson contains a feedback-type insight (something that should change how Claude behaves in future sessions), suggest saving it as a memory entry too. Do not save automatically — ask first.
