# Architecture Patterns

Common workspace designs, from simplest to most complex.
Choose the simplest pattern that covers the user's actual needs.

---

## Pattern 1: Minimal (most projects start here)

**When to use**: Single domain, few pain points, no safety-critical operations.

```
~/work/project/
├── CLAUDE.md                    # Stack, commands, conventions
└── .claude/
    └── rules/                   # Optional: split large CLAUDE.md sections
        └── code-style.md
```

**What you get**: Claude knows your project. That's often enough.

**Upgrade signal**: You find yourself repeatedly explaining the same thing
to Claude, or pasting the same workflow steps.

---

## Pattern 2: Skills-only

**When to use**: Repeatable domain knowledge, no need for isolation or
different permissions.

```
~/work/project/
├── CLAUDE.md
└── .claude/
    ├── skills/
    │   ├── testing-patterns/
    │   │   └── SKILL.md
    │   └── api-conventions/
    │       └── SKILL.md
    └── rules/
        └── safety.md
```

**What you get**: Claude applies domain knowledge automatically when relevant.
No commands, no agents — skills trigger by description matching.

**Upgrade signal**: Skills produce verbose output that clutters your context,
or you need different permissions for different tasks.

---

## Pattern 3: Commands + Skills

**When to use**: Repeatable workflows you invoke by name, plus domain knowledge.

```
~/work/project/
├── CLAUDE.md
└── .claude/
    ├── commands/
    │   ├── deploy-check.md      # Utility: self-contained workflow
    │   └── morning.md           # Utility: daily routine
    ├── skills/
    │   ├── testing-patterns/
    │   │   └── SKILL.md
    │   └── api-conventions/
    │       └── SKILL.md
    └── rules/
        └── safety.md
```

**What you get**: /commands for actions, skills for knowledge.
Commands run in your main context — no isolation.

**Upgrade signal**: Commands spawn long-running investigations that
bloat your context, or you need read-only vs write separation.

---

## Pattern 4: Single Agent + Skills

**When to use**: One domain that benefits from isolation but doesn't need
multiple specialists.

```
~/work/project/
├── CLAUDE.md
└── .claude/
    ├── agents/
    │   └── project-expert.md    # Single agent, preloads relevant skills
    ├── commands/
    │   └── investigate.md       # Routes to agent
    ├── skills/
    │   ├── domain-knowledge/
    │   │   └── SKILL.md
    │   └── debugging-patterns/
    │       └── SKILL.md
    └── rules/
        └── safety.md
```

**What you get**: /investigate spawns an isolated agent that returns a summary.
Main context stays clean. Agent preloads domain skills.

**Upgrade signal**: The single agent covers too many different permission
levels, or different tasks need different models.

---

## Pattern 5: Specialist Agents (Command → Agent → Skill)

**When to use**: Multiple domains with different permission/model/context needs.
This is the full orchestration pattern.

```
~/.claude/                              # GLOBAL
├── CLAUDE.md                           # Profile + universal rules
├── agents/                             # All agents global
│   ├── domain-a-reader.md              # Read-only, sonnet
│   ├── domain-a-operator.md            # Read-write, sonnet
│   ├── domain-b-guardian.md            # Read-only, sonnet
│   └── incident-commander.md           # Full access, opus, memory
└── commands/
    └── morning.md                      # Cross-project utility

~/work/project/                         # PROJECT
├── CLAUDE.md                           # Project details (Layer 3)
├── .claude/
│   ├── skills/                         # Project-specific skills
│   │   ├── health-check/
│   │   │   ├── SKILL.md
│   │   │   ├── scripts/check.sh
│   │   │   └── references/failures.md
│   │   └── sync-check/
│   │       └── SKILL.md
│   ├── commands/                       # Project commands route to agents
│   │   ├── diagnose.md                 # → domain-a-reader
│   │   ├── operate.md                  # → domain-a-operator
│   │   └── incident.md                 # → incident-commander
│   └── hooks/
│       └── safety-gate.sh              # PreToolUse: block destructive ops
```

**What you get**: Deterministic routing, permission boundaries,
model optimization, lean context per agent.

**Upgrade signal**: You rarely need to upgrade past this. If you do,
consider Agent Teams for parallel work across specialists.

---

## Pattern 6: Full Infrastructure (rare, team use)

**When to use**: Team-shared workspace, CI/CD integration, scheduled
maintenance, multiple domains.

Adds to Pattern 5:
```
~/work/project/
├── .claude/
│   ├── hooks/
│   │   ├── safety-gate.sh              # PreToolUse
│   │   ├── skill-eval.sh               # UserPromptSubmit
│   │   ├── skill-eval.js               # Confidence scoring engine
│   │   ├── skill-rules.json            # Trigger patterns
│   │   └── auto-format.sh              # PostToolUse
│   └── settings.md                     # Human-readable hook documentation
│
└── .github/workflows/                  # (or Azure Pipelines equivalent)
    ├── pr-review.yml                   # Auto PR review
    ├── weekly-quality.yml              # Scheduled quality sweep
    └── docs-sync.yml                   # Monthly docs alignment
```

**What you get**: Everything from Pattern 5, plus automated quality gates,
skill auto-suggestion for freeform prompts, CI integration.

---

## Choosing the right pattern

| User says... | Start with |
|-------------|-----------|
| "I just want Claude to know my project" | Pattern 1 (Minimal) |
| "I keep explaining the same testing patterns" | Pattern 2 (Skills-only) |
| "I do the same deployment check every day" | Pattern 3 (Commands + Skills) |
| "My investigations clutter my context" | Pattern 4 (Single Agent) |
| "I need read-only diagnosis AND write operations" | Pattern 5 (Specialists) |
| "My team shares this workspace and we have CI" | Pattern 6 (Full Infrastructure) |
| "I'm not sure what I need" | Pattern 1, then grow |

---

## Agent design templates

When recommending agents, use these templates based on role.

### Diagnostician (read-only investigation)
```yaml
---
name: [domain]-diagnostician
description: >
  Diagnose [domain] issues. Use when [specific triggers].
model: sonnet
tools: Bash([tool] get*), Bash([tool] describe*), Bash([tool] logs*), Read, Grep, Glob
skills:
  - [relevant-skill]
---

You are a senior [domain] diagnostician.

## Process
1. Gather information using available tools
2. Identify the failure pattern using your preloaded skills
3. Present findings in the structured format below

## Output Format
1. Problem — what's wrong
2. Impact — what's affected
3. Root Cause — why it happened
4. Fix — exact commands (but do NOT execute — you are read-only)
5. Prevention — how to avoid next time
```

### Operator (can modify system)
```yaml
---
name: [domain]-operator
description: >
  Execute operations on [domain]. Use when [specific triggers].
model: sonnet
tools: Bash([tool]*), Read, Write, Grep, Glob
skills:
  - [relevant-skill]
---

You are a senior [domain] operator.

## Process
1. Understand the requested change
2. Verify current state
3. Execute the change with rollback preparation
4. Verify the result

## Safety
- Always show the change plan before executing
- Include rollback commands for every modification
- Verify success after each step
```

### Incident Commander (deep reasoning, memory)
```yaml
---
name: incident-commander
description: >
  Coordinate incident response across [domains].
  Use for complex, multi-system issues.
model: opus
tools: Bash, Read, Write, Grep, Glob
memory: project
skills:
  - [diagnostic-skill]
  - [incident-patterns-skill]
---

You are an incident commander.

## Process
1. Triage — assess severity and blast radius
2. Investigate — use diagnostic skills and available tools
3. Correlate — check multiple systems for related failures
4. Resolve — propose and execute fix (with confirmation)
5. Document — update incident notes and memory

## After resolution
Update your memory with the failure pattern for future reference.
```

### Researcher (web/doc research, no project skills needed)
```yaml
---
name: researcher
description: >
  Research topics using web search and documentation.
  Use when the user needs information beyond the codebase.
model: sonnet
tools: WebSearch, WebFetch, Read, Write
---

You are a senior technical researcher.

## Process
1. Clarify the research question
2. Search multiple sources
3. Synthesize findings
4. Present a structured summary with source links
```

---

## Skill design templates

### Knowledge skill (conventions, patterns)
```yaml
---
name: [domain]-conventions
description: >
  [Domain] conventions and patterns for this project.
  Use when writing [specific things] or reviewing [domain] code.
---

# [Domain] Conventions

## Patterns
[The 80% use cases]

## Anti-patterns
[What NOT to do, with WHY]

## Gotchas
(Add failure patterns as you discover them)
```

### Diagnostic skill (with script)
```yaml
---
name: [domain]-health-check
description: >
  Check [domain] health and diagnose issues. Use when [triggers].
---

# [Domain] Health Check

## Quick check
Run `scripts/check.sh` and analyze the output.

## Interpreting results
[How to read the script output]

## Common failure patterns
For detailed failure patterns, read `references/common-failures.md`.
```

### Workflow skill (step-by-step, user-invoked)
```yaml
---
name: deploy-check
description: Pre-deployment verification checklist.
disable-model-invocation: true
---

# Deploy Check

## Steps
1. Run the test suite: `scripts/run-tests.sh`
2. Check for uncommitted changes
3. Verify the target environment
4. Confirm with user before proceeding
```
