# CC Toolkit — Claude Code Workspace Design & Audit Skills

**Two skills that work together: one designs your workspace, the other validates it.**

---

## The problem these skills solve

Most Claude Code setups fail in one of two ways:

**Over-engineering.** The user reads about Command → Agent → Skill orchestration, builds 8 agents, 15 skills, a hook system, and a skill-eval engine — for a project that needed a CLAUDE.md and maybe two skills. The setup consumes context tokens, adds latency, and creates maintenance burden that outweighs the benefit.

**Under-engineering.** The user throws everything into a 500-line CLAUDE.md and wonders why Claude ignores half the rules by line 200. Or they build skills with vague descriptions that never trigger. Or they create "god agents" that do everything with no permission boundaries.

Both failures come from the same root cause: **no decision framework for what components to build and how to evaluate them.** The official docs explain what each component does, but not when to use each one or how they interact.

These two skills fill that gap.

---

## How they were built

This toolkit was distilled from a deep-dive research session covering:

**Official sources:**
- The `anthropics/skills` repository (69k+ stars) — Anthropic's official skill examples and the production document skills that power Claude's native capabilities
- The `agentskills.io` specification — the open standard for SKILL.md format
- Anthropic's `skill-creator` meta-skill — the internal tool for building and evaluating skills
- Official Claude Code docs at `code.claude.com/docs` — subagents, skills, hooks, memory, settings

**Production showcases from the community:**
- `diet103/claude-code-infrastructure-showcase` (9k stars) — hook-based skill auto-activation, progressive disclosure pattern, dev docs system. Born from 6 months of production use across 6 TypeScript microservices
- `ChrisWiles/claude-code-showcase` (3.8k stars) — skill-eval engine with confidence scoring, scheduled GitHub Actions, JIRA integration, LSP integration. A real production team's configuration
- `shanraisshan/claude-code-best-practice` (19.7k stars) — 84 tips from Boris Cherny (creator of Claude Code), Thariq, Cat Wu, Lydia Hallie, and other Anthropic engineers. Working Command → Agent → Skill demo

**Direct insights from the Claude Code team:**
- Boris Cherny: "Skills descriptions are the #1 trigger failure point", "Use Opus for plan mode and Sonnet for code", "Vanilla CC is better than any workflows for smaller tasks", "Agentic search (glob + grep) beats RAG"
- Thariq: "Build a Gotchas section in every skill", "Don't state the obvious — focus on what pushes Claude out of its default behavior", "Use `context: fork` to run a skill in an isolated subagent", "Embed `!`command`` in SKILL.md for dynamic context"
- Lydia Hallie: "Use on-demand hooks in skills", "Measure skill usage with PreToolUse hooks"

Every rule in the toolkit traces back to one of these sources. Nothing is theoretical — it's all proven in production.

---

## What's in the toolkit

```
cc-toolkit/
├── cc-setup-auditor/                        # Evaluates existing workspaces
│   ├── SKILL.md                          # 205 lines — 2-phase workflow
│   ├── references/
│   │   └── conditional-rules.md          # 247 lines — 92 rules with preconditions
│   └── scripts/
│       └── discover.sh                   # 279 lines — scans workspace + maps relationships
│
└── cc-workspace-design/                  # Designs new workspaces
    ├── SKILL.md                          # 237 lines — 5-stage interview-driven design
    └── references/
        ├── classification-engine.md      # 161 lines — decision tree for each task
        └── architecture-patterns.md      # 360 lines — 6 patterns from simple to complex
```

---

## Skill 1: cc-setup-auditor

### What it does

Evaluates your Claude Code workspace configuration against 92 best-practice rules — but unlike a flat checklist, it first **understands your architecture** and then applies only the rules that are relevant.

### Why conditional evaluation matters

A flat checklist gives contradictory advice. Here's what happens when you run a generic "Claude Code best practices" checklist against a real workspace:

**Flat checklist says:**
> "Skill description should be pushy with trigger phrases"

**But your skill has `user-invocable: false` because it's only preloaded into an agent via `skills:` frontmatter. The description is never used for triggering. Making it "pushy" wastes tokens and could cause false triggers if the skill is also auto-discoverable.**

**Flat checklist says:**
> "Split into specialist agents for different domains"

**But your project has 2 skills and 1 agent. It's complexity tier Simple. Adding specialist agents would be over-engineering — vanilla CC with a good CLAUDE.md would serve you better.**

**Flat checklist says:**
> "Add PreToolUse safety hooks to block destructive commands"

**But your agent already has `tools: Bash(kubectl get*), Bash(kubectl describe*), Read, Grep` — destructive commands are impossible because the tool allowlist doesn't include them. The hook would never fire.**

The cc-setup-auditor avoids all of these by running two phases:

**Phase 1: Comprehension** — scans everything, builds a relationship map (which commands route to which agents, which agents preload which skills, which hooks cover which paths), classifies each component's role, and determines the complexity tier.

**Phase 2: Evaluation** — reads the conditional rules and applies only those whose preconditions are met by the architecture discovered in Phase 1. Rules that don't apply are explicitly marked as SKIP with the reason.

### Example output

Here's what the cc-setup-auditor produces for a real Kubernetes workspace with the Command → Agent → Skill pattern:

```
============================================================
  SETUP AUDITOR — EVALUATION REPORT
============================================================

Architecture Summary
  Pattern: Command → Agent → Skill (deterministic routing)
  Complexity: MODERATE (4 skills, 2 agents, 3 commands, 1 hook)
  Primary flow: /k8s-health → k8s-diagnostician → [health-check]
                /k8s-incident → incident-commander → [health-check, incident-patterns]
  Freeform fallback: None (all routing via commands)

============================================================

## health-check (role: diagnostic, invocation: agent-preloaded)

  PASS  A1.1  Dir name matches name: field (health-check = health-check)
  PASS  A1.2  SKILL.md exists and named correctly
  PASS  A1.4  Name format valid (lowercase, hyphens)
  PASS  A1.5  Description present (387 chars)
  PASS  A1.6  Description under 1024 chars
  PASS  A1.7  No angle brackets in description
  SKIP  A2.1  "Description pushy" — skill is exclusively agent-preloaded
              (listed in k8s-diagnostician skills: field), description
              is never used for triggering. Pushy description not needed.
  SKIP  A2.3  "Lists trigger keywords" — same reason: agent-preloaded only.
  PASS  A3.1  SKILL.md is 142 lines (under 500, single focused domain —
              splitting to references/ would add complexity without benefit)
  SKIP  A3.2  "Progressive disclosure" — skill is under 200 lines
              with no distinct sub-topics.
  PASS  A3.3  Scripts run via bash (scripts/cluster-health.sh)
  ISSUE A3.5  No Gotchas section. This skill has been in use — add failure
              patterns you've discovered. (HIGH)
              Recommendation: Add "## Gotchas" section with common failures
              like "kubectl times out on large clusters — increase timeout".
  PASS  A3.7  Gives goals + constraints, not prescriptive steps
  SKIP  A3.10 "Dynamic context via !`command`" — skill uses a script that
              gathers live data. !`command` would be redundant.
  SKIP  A4.1  "Use context: fork" — skill is already preloaded into
              k8s-diagnostician agent which provides isolation.

  Score: 8 PASS / 1 ISSUE / 5 SKIP
  Priority fix: Add Gotchas section (HIGH)

============================================================

## k8s-diagnostician (role: diagnostician, invocation: command-routed)

  PASS  B1.*  Should be an agent: YES
              - Needs own context (reads pod logs, events — verbose)
              - Needs restricted tools (read-only kubectl)
              - Work is self-contained (returns diagnosis summary)
  PASS  B2.1  Prompt body is 34 lines (under 80)
  PASS  B2.2  Focuses on WHO + HOW + OUTPUT
  PASS  B2.3  Domain knowledge in preloaded health-check skill, not prompt
  PASS  B2.4  Output format specified (Problem/Impact/Root Cause/Fix/Prevention)
  SKIP  B2.5  "Safety rules explicit" — agent has tools scoped to read-only
              (Bash(kubectl get*), Bash(kubectl describe*), Bash(kubectl logs*)).
              Cannot run destructive commands. Explicit safety rules unnecessary.
  PASS  B2.6  Model: sonnet (appropriate for standard diagnostics)
  SKIP  B2.7  "Persistent memory" — one-shot diagnostics, no accumulation benefit.
  PASS  B3.1  Tools scoped: Bash(kubectl get*), Bash(kubectl describe*),
              Bash(kubectl logs*), Read, Grep, Glob
  PASS  B4.1  Single domain (k8s diagnostics)
  PASS  B5.1  Layer 1 baked in (cluster names, namespaces in prompt)

  Score: 9 PASS / 0 ISSUE / 2 SKIP

============================================================

## incident-commander (role: orchestrator, invocation: command-routed)

  PASS  B1.*  Should be an agent: YES
              - Deep reasoning needed (multi-system correlation)
              - Different model justified (opus for complex incidents)
              - Persistent memory justified (learns from past incidents)
  PASS  B2.1  Prompt body is 52 lines (under 80)
  PASS  B2.6  Model: opus (appropriate for incident investigation)
  PASS  B2.7  memory: project (accumulates incident patterns)
  ISSUE B3.1  Tools not scoped — inherits all tools. This agent has write
              access but no explicit allowlist. (HIGH)
              Recommendation: Add `tools: Bash, Read, Write, Grep, Glob`
              and consider restricting Bash to specific commands.
  ISSUE B2.5  Safety rules minimal — agent can write but only says
              "confirm before destructive operations". Should explicitly
              list which operations require confirmation. (MEDIUM)

  Score: 6 PASS / 2 ISSUE / 0 SKIP
  Priority fixes:
    1. Scope tools (HIGH)
    2. Expand safety rules (MEDIUM)

============================================================

## /k8s-health (role: router, invocation: user-typed)

  PASS  C1.1  Thin router — spawns k8s-diagnostician, passes $ARGUMENTS
  PASS  C1.2  Doesn't duplicate agent prompt (12 lines total)
  PASS  C1.3  Deterministic routing (always → k8s-diagnostician)
  PASS  C1.4  $ARGUMENTS passed through
  PASS  C1.5  description: present in frontmatter

  Score: 5 PASS / 0 ISSUE / 0 SKIP

============================================================

## PreToolUse safety hook

  PASS  D1.1  Safety hook exists (blocks kubectl delete, drain, cordon)
  PASS  D1.2  Uses PreToolUse (fires on agent path)
  PASS  D1.3  Covers agent path (tested: fires when k8s-diagnostician
              runs kubectl, not just on user prompts)
  PASS  D1.4  Exit code 2 for blocking
  SKIP  D2.1  "Skill-eval hook" — all routing is via commands.
              No freeform skill matching used. Skill-eval hook unnecessary.
  SKIP  D3.1  "Stop hook for quality" — agents return structured output
              that user reviews. Automated verification adds no value here.

  Score: 4 PASS / 0 ISSUE / 2 SKIP

============================================================

## Cross-Component Findings

  PASS  F1.1  Over-engineering check — Moderate complexity with
              2 agents covering distinct needs (read-only vs full access).
              Orchestration is justified.
  PASS  F1.3  No double invocation risk — no skill-eval hook, all
              routing via commands.
  ISSUE F1.5  Context budget: incident-commander preloads health-check
              (142 lines) + incident-patterns (287 lines) = 429 lines
              injected at startup. Acceptable but approaching the limit.
              Monitor if adding more skills. (LOW)
  PASS  F2.1  All skills have invocation paths
              (health-check: agent-preloaded by both agents,
               incident-patterns: agent-preloaded by incident-commander)
  PASS  F2.2  All agents reachable via commands
  PASS  F2.3  Safety hooks cover all tool-use paths
  WARN  F2.4  No freeform fallback — if user types "my pod is crashing"
              without using /k8s-health, skills won't auto-trigger.
              Consider adding auto-invocable descriptions to skills
              OR accept this is by design (commands-only workflow). (LOW)
  PASS  F3.1  Vanilla CC tasks stay vanilla (simple kubectl queries
              don't go through orchestration)

============================================================

## Prioritized Recommendations

  1. HIGH   — incident-commander: Scope tools with explicit allowlist
  2. HIGH   — health-check: Add Gotchas section
  3. MEDIUM — incident-commander: Expand safety rules
  4. LOW    — Monitor context budget as skills grow
  5. LOW    — Consider freeform fallback (optional, by design)
  6. N/A    — Skill descriptions: not relevant (all agent-preloaded)
  7. N/A    — Skill-eval hook: not relevant (command-routed)
  8. N/A    — Stop hooks: not relevant (user reviews output)
  9. N/A    — context: fork: not relevant (agents provide isolation)

============================================================
```

Notice what the auditor **doesn't say**:
- It doesn't tell you to make skill descriptions "pushy" — because all skills are agent-preloaded
- It doesn't recommend a skill-eval hook — because all routing is via commands
- It doesn't suggest `context: fork` — because agents already provide isolation
- It doesn't recommend splitting agents further — because two specialists with different models/permissions is the right level for this setup

The SKIP and N/A entries are as valuable as the PASS/ISSUE entries — they show the evaluation understood the architecture.

---

## Skill 2: cc-workspace-design

### What it does

Designs a Claude Code workspace from scratch through structured conversation. Instead of stamping out a template, it interviews you about your actual work, classifies each task into the right component type, and recommends only what's justified.

### Why interview-driven design matters

Most "Claude Code setup guides" show you a fully-built workspace and say "copy this." But their workspace was built for their project — React/TypeScript with JIRA and GitHub Actions. Your project might be Kubernetes administration with Azure DevOps and ArgoCD. The components don't translate 1:1.

The cc-workspace-design starts from your pain points, not from a template.

### The 5-stage process

```
Interview → Classify → Design → Draft → Install
```

**Stage 1** asks about your domain, tools, pain points, and workflows — in rounds, not all at once.

**Stage 2** runs each task through a decision tree:

```
Is this a constraint that should ALWAYS apply?
  → CLAUDE.md rule

Does Claude handle it fine already?
  → Nothing (vanilla CC)

Repeatable named sequence?
  → Command (self-contained or router)

Domain knowledge Claude needs?
  → Skill (simple, with scripts, or with references)

Needs isolation or different permissions?
  → Agent (with scoped tools and specific model)

Dangerous operation?
  → PreToolUse safety hook
```

**Stage 3** picks from 6 architecture patterns:

| Pattern | Complexity | When |
|---------|-----------|------|
| Minimal | CLAUDE.md only | "I just want Claude to know my project" |
| Skills-only | + skills | "I keep explaining the same patterns" |
| Commands + Skills | + commands | "I do the same workflow every day" |
| Single Agent | + 1 agent | "My investigations clutter my context" |
| Specialists | + multiple agents | "I need read-only AND write operations" |
| Full Infrastructure | + hooks + CI | "My team shares this and we have CI/CD" |

**Stage 4** drafts actual files using role-specific templates (diagnostician, operator, incident-commander, researcher for agents; knowledge, diagnostic, workflow for skills).

**Stage 5** produces exact shell commands for installation.

### Example session

Here's a condensed example of the cc-workspace-design helping a DevOps engineer:

```
User: Help me set up Claude Code for my K8s + Azure DevOps workflow.

Architect: Let me understand your setup first.

  Round 1: What tools do you use daily?
  User: kubectl, ArgoCD CLI, Azure DevOps pipelines, SonarQube, SSH to VMs

  Round 2: What wastes the most time?
  User: Debugging pod crashes takes 20+ minutes of gathering info.
        Writing pipeline YAML is error-prone.
        I forget the exact ArgoCD sync commands.

  Round 3: Walk me through pod debugging.
  User: I run kubectl describe pod, then kubectl logs, then check events,
        then check node status, then check ArgoCD sync — lots of switching.

  Round 4: Any safety concerns?
  User: Yes — accidentally running kubectl delete in production.

──────────────────────────────────────────────────

Classification:

| Task | Classification | Component | Reasoning |
|------|---------------|-----------|-----------|
| Quick kubectl query | Vanilla CC | None | Claude handles this without help |
| Pod crash debugging | Agent + skill | k8s-diagnostician + health-check | Verbose output (reads logs, events, descriptions), needs isolation to keep main context clean |
| Pipeline YAML writing | Skill | pipeline-conventions | Domain knowledge about Azure Pipelines patterns — Claude applies while writing |
| ArgoCD sync commands | CLAUDE.md rule | .claude/rules/argocd.md | Always-on reference, under 20 lines |
| K8s naming conventions | CLAUDE.md rule | CLAUDE.md | 5-line constraint that applies everywhere |
| Block kubectl delete | Safety hook | PreToolUse hook | Must fire on ALL paths including agent |

Do you agree? Should I adjust anything?

──────────────────────────────────────────────────

Design: Pattern 4 (Single Agent + Skills)

  ~/work/k8s/
  ├── CLAUDE.md                         # Stack, namespaces, ArgoCD conventions
  ├── .claude/
  │   ├── agents/
  │   │   └── k8s-diagnostician.md      # Sonnet, read-only kubectl, preloads health-check
  │   ├── skills/
  │   │   ├── health-check/
  │   │   │   ├── SKILL.md              # Diagnostic workflow
  │   │   │   └── scripts/check.sh      # Gathers pod/node/event data as JSON
  │   │   └── pipeline-conventions/
  │   │       └── SKILL.md              # Azure Pipelines patterns
  │   ├── commands/
  │   │   └── k8s-debug.md              # /k8s-debug → spawns k8s-diagnostician
  │   ├── hooks/
  │   │   └── k8s-safety.sh             # Blocks kubectl delete/drain/cordon
  │   └── rules/
  │       └── argocd.md                 # ArgoCD sync commands reference

  NOT building (and why):
  - No skill-eval hook: only 2 skills, commands handle routing
  - No incident-commander agent: not requested, start simple
  - No specialist split: one agent is enough for now
  - No Stop hooks: user reviews output directly
  - No scheduled tasks: no CI/CD automation requested yet

Confirm this design?

──────────────────────────────────────────────────

[After confirmation, Stage 4 drafts all files, Stage 5 gives install commands]
```

Notice what the architect **chose not to build**: no skill-eval hook (only 2 skills), no specialist agent split (one domain), no Stop hooks, no scheduled tasks. It explains each omission. This prevents the over-engineering trap.

---

## Installation

```bash
# Extract to your project (skills available in this project only)
tar xzf cc-toolkit.tar.gz -C .claude/skills/

# OR extract to global scope (available in all projects)
tar xzf cc-toolkit.tar.gz -C ~/.claude/skills/
```

## Usage

### Audit an existing workspace

```
Use the cc-setup-auditor skill to evaluate my workspace.
```

Or target specific components:

```
Use cc-setup-auditor to audit only my agents.
```

```
Use cc-setup-auditor to check if my k8s-commander should be one agent or split.
```

### Design a new workspace

```
Use the cc-workspace-design skill. I'm setting up a workspace for
managing Kubernetes clusters. Interview me to figure out what I need.
```

### Grow an existing workspace

```
Use cc-workspace-design. I already have a basic k8s setup.
I'm adding SonarQube monitoring. What components should I add?
```

### Run both in sequence

```
Use cc-workspace-design to plan my workspace, then use cc-setup-auditor
to validate the result before I start building.
```

---

## What makes this different from other Claude Code guides

**Most guides give you a template.** Copy this CLAUDE.md, copy these agents, copy these hooks. But their project isn't your project. Their pain points aren't yours.

**The cc-setup-auditor gives you conditional evaluation.** 92 rules, each with a precondition. A rule that doesn't apply is explicitly skipped with the reason — so you know the evaluation understood your design intent, not just ran a checklist.

**The cc-workspace-design gives you interview-driven design.** It asks about your work before recommending anything. Then it classifies each task into the simplest component that solves it. It tells you what NOT to build and why. It picks from 6 architecture patterns, not one template.

**Both follow the progressive disclosure pattern they recommend.** SKILL.md under 250 lines, detailed content in references/, scripts/ for automation. They practice what they preach.

---

## Research sources

| Source | Stars | What we extracted |
|--------|-------|------------------|
| `anthropics/skills` | 69k+ | Canonical SKILL.md format, progressive disclosure, description patterns, production skill examples |
| `agentskills.io` specification | — | Frontmatter field specs, naming rules, folder structure requirements |
| Anthropic's `skill-creator` meta-skill | — | "Description is the #1 trigger failure point", "be pushy", eval loop methodology |
| `diet103/claude-code-infrastructure-showcase` | 9k | Hook-based skill auto-activation, 500-line rule, dev docs pattern |
| `ChrisWiles/claude-code-showcase` | 3.8k | Skill-eval engine with confidence scoring, scheduled GitHub Actions, JIRA integration |
| `shanraisshan/claude-code-best-practice` | 19.7k | 84 tips from Claude Code team, Command → Agent → Skill demo, cross-model workflow |
| `code.claude.com/docs` (official) | — | Subagent frontmatter fields, hook event firing matrix, memory system, settings scopes |
| Boris Cherny (Claude Code creator) | — | "Vanilla CC beats workflows for small tasks", model splitting by phase, "prototype > PRD" |
| Thariq (Claude Code team) | — | `context: fork`, Gotchas sections, `!`command`` dynamic context, on-demand hooks in skills |
| Community consensus | — | 50% compaction threshold, "agent dumb zone", scope discipline |

---

## License

MIT — use freely in any project.
