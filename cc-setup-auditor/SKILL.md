---
name: cc-setup-auditor
description: >
  Audit and evaluate Claude Code workspace configuration for best practices
  with context-aware analysis. Reviews the full architecture — agents, skills,
  commands, hooks, CLAUDE.md, and their relationships — then applies checks
  conditionally based on each component's role and purpose. Use when the user
  wants to review their setup, validate agents or skills, improve triggering,
  check orchestration patterns, or asks anything about whether their Claude
  Code configuration follows best practices — even if they just say "review
  my setup" or "is this agent correct".
---

# Setup Auditor

Evaluate a Claude Code workspace by first understanding its architecture,
then applying best-practice checks conditionally — only where they are
relevant, never blindly.

## Why conditional evaluation matters

A flat checklist produces contradictions:
- "Make description pushy" → but the skill is `user-invocable: false`, only called by agents
- "Split into specialist agents" → but the project is simple, vanilla CC is better
- "Use `context: fork`" → but the skill is already preloaded into an isolated agent
- "Add PreToolUse safety hooks" → but the agent's `tools:` is already scoped to read-only

Every check has a precondition. The precondition depends on understanding
the full architecture first.

---

## Phase 1: Architecture Comprehension

Run this FIRST, COMPLETELY, before evaluating anything.

### Step 1.1: Discover all components

Run the discovery script to inventory everything:

```bash
bash scripts/discover.sh .
```

This produces a JSON summary of all components, their properties,
and — critically — the relationships between them.

Also manually scan for components the script might miss:

```bash
# Global agents and skills
ls ~/.claude/agents/ 2>/dev/null
ls ~/.claude/skills/ 2>/dev/null
ls ~/.claude/commands/ 2>/dev/null

# Global CLAUDE.md
cat ~/.claude/CLAUDE.md 2>/dev/null | head -5
```

### Step 1.2: Build the relationship map

For each command, read it and note which agent it spawns.
For each agent, read its frontmatter and note which skills it preloads.
For each skill, check if it uses `context: fork`, `user-invocable: false`,
or `disable-model-invocation: true`.

Build a map like this (adapt to what you find):

```
ROUTING MAP:
  /command-a → agent-x → [skill-1, skill-2]
  /command-b → agent-y → [skill-1, skill-3]
  Freeform prompts → skill-eval hook → [skill-1, skill-2, skill-3, skill-4]
  skill-4 is standalone (no agent preloads it)

SCOPE MAP:
  Global agents: [agent-x, agent-y, researcher]
  Project skills: [skill-1, skill-2, skill-3]
  Global skills: [skill-4]
  Project commands: [command-a, command-b]
  Global commands: [morning, handoff]

SAFETY MAP:
  PreToolUse hooks: [present / absent]
  Agent tool restrictions: {agent-x: read-only, agent-y: full}
  Skills with destructive scripts: [none / list]
```

### Step 1.3: Classify each component's role

Assign a role to every component. This determines which checks apply.

**Agent roles:**
- `diagnostician` — read-only investigation, returns findings
- `operator` — can modify the system, needs safety gates
- `researcher` — web/doc research, no project-specific skills needed
- `orchestrator` — coordinates other agents or multi-step workflows
- `reviewer` — quality/security review of code or configs

**Skill roles:**
- `knowledge` — conventions, patterns, reference material (e.g., api-conventions)
- `workflow` — step-by-step task execution (e.g., deploy-check)
- `diagnostic` — runs scripts, analyzes output (e.g., health-check)
- `generator` — produces files or output from templates (e.g., report-writer)
- `context-loader` — routes to docs, provides decision trees (e.g., product-self-knowledge)

**Command roles:**
- `router` — thin entry point that spawns an agent
- `workflow` — multi-step instructions executed in main context
- `utility` — quick standalone action (commit, handoff)

**Hook roles:**
- `safety-gate` — blocks dangerous operations (PreToolUse)
- `skill-eval` — suggests skills for freeform prompts (UserPromptSubmit)
- `quality-gate` — verifies output before completion (Stop)
- `formatter` — auto-formats or auto-lints (PostToolUse)
- `tracker` — logs tool usage for analytics (PostToolUse)

### Step 1.4: Determine the complexity tier

| Tier | Indicators | Implication |
|------|-----------|-------------|
| **Simple** | <3 skills, no multi-agent routing, single domain | Many checks don't apply. Vanilla CC may be better than orchestration |
| **Moderate** | 3-6 skills, 1-2 agents, basic command routing | Standard best practices apply. Focus on description quality and scope |
| **Complex** | 6+ skills, specialist agents, hook systems, multi-domain | Full orchestration justified. Cross-component analysis matters most |

### Step 1.5: Identify the invocation patterns

For each skill, determine HOW it gets invoked. This is critical because
different invocation paths require different optimization:

| Pattern | How skill is reached | What matters |
|---------|---------------------|-------------|
| **Agent-preloaded** | Agent has `skills: [this-skill]` in frontmatter | Description quality irrelevant (agent always loads it). Focus on content quality and keeping it lean (full body injected at agent startup) |
| **Command-routed** | Command explicitly tells Claude to use this skill | Description quality irrelevant. Focus on the command→skill interface |
| **Auto-invoked** | Claude matches description to user's freeform prompt | Description quality is CRITICAL. Must be "pushy" with trigger phrases |
| **User-invoked** | User types `/skill-name` directly | Description shown in /menu. Must be clear to humans, not just Claude |
| **Fork-isolated** | Skill has `context: fork` — runs in isolated subagent | Focus on what the summary returns to main context |
| **Mixed** | Skill used by multiple patterns above | Must satisfy requirements of ALL its invocation patterns |

---

## Phase 2: Contextual Evaluation

Now read `references/conditional-rules.md` and apply ONLY the rules
whose preconditions are met by the architecture you discovered in Phase 1.

For each component, evaluate it against the matching rules and produce findings.

### Output format

#### Architecture Summary
```
Pattern: [Command→Agent→Skill / Freeform-only / Mixed / Simple vanilla]
Complexity: [Simple / Moderate / Complex]
Components: X agents, Y skills, Z commands, N hooks
Key relationship: [describe the primary routing flow]
```

#### Per-Component Findings

For each component, report ONLY relevant findings:

```
## [component-name] (role: [role], invocation: [pattern])

PASS: [check that passed — brief note]
ISSUE: [check that failed — specific finding + why it matters for THIS architecture]
SKIP: [check that was skipped — why the precondition wasn't met]

Recommendation: [specific fix, tied to the component's role in the architecture]
```

Include SKIP entries for important checks that DIDN'T apply — this shows
the evaluation was context-aware, not just running fewer checks.

#### Cross-Component Findings

After individual evaluations, look for:

- **Redundancy**: Same knowledge in both agent prompt and preloaded skill
- **Gaps**: Agent has no preloaded skills but references domain knowledge
- **Conflicts**: Command routes to agent, but skill-eval hook also matches
  the same skill → double invocation risk
- **Scope mismatches**: Project skill referenced by global agent (won't load
  when running from outside the project)
- **Over-engineering**: Full orchestration for tasks that vanilla CC handles fine
- **Under-engineering**: Complex multi-domain work with no agent isolation

#### Prioritized Recommendations

Rank by impact for THIS SPECIFIC architecture:

1. **CRITICAL** — Will cause failures or silent misbehavior
2. **HIGH** — Significant quality/safety impact given the design
3. **MEDIUM** — Best practice violations relevant to this complexity tier
4. **LOW** — Polish items
5. **NOT APPLICABLE** — Checks that exist but don't apply to this architecture

---

## Reference files

- `references/conditional-rules.md` — All evaluation rules with preconditions.
  READ THIS before evaluating. Each rule states when it applies and when to skip it.
