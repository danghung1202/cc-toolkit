---
name: cc-workspace-design
description: >
  Design Claude Code workspace configurations from scratch for new projects
  or domains. Interviews the user about their tools, workflows, and pain points,
  then recommends the right mix of agents, skills, commands, hooks, and CLAUDE.md
  structure — calibrated to the actual complexity needed, not a one-size-fits-all
  template. Use when the user wants to set up Claude Code for a new project,
  plan their agent/skill architecture, brainstorm what components they need,
  or says things like "help me set up Claude Code for my project",
  "what agents do I need", or "design my workspace".
---

# Workspace Architect

Design a Claude Code workspace configuration through structured conversation.
The goal is to recommend ONLY the components that are justified for the user's
actual needs — not to fill every slot with agents and skills because they exist.

## Core principle

> Not every project needs agents. Not every task needs a skill.
> The best architecture is the simplest one that solves the actual pain points.

A kubectl one-liner doesn't need a Command→Agent→Skill chain.
A complex multi-domain incident response workflow does.
This skill helps find the right level.

---

## Stage 1: Interview

Conduct a focused interview. Don't dump all questions at once — ask in
rounds based on what you learn. Use the AskUserQuestion tool when available.

### Round 1: The domain

Understand what the workspace is for:

- What is this project/workspace about? (e.g., "managing Kubernetes clusters",
  "building a SaaS product", "DevOps automation")
- What tools do you use daily? (CLI tools, APIs, platforms)
- What's your tech stack? (languages, frameworks, infrastructure)

### Round 2: The pain points

Understand what wastes time today:

- What tasks do you repeat multiple times per day?
- What tasks require you to remember specific commands or sequences?
- What tasks are error-prone or risky?
- What tasks involve switching between multiple tools?
- Where do you lose context between sessions?

### Round 3: The workflows

For each pain point identified, dig deeper:

- Walk me through how you do this task today, step by step
- What information do you need to gather before starting?
- What could go wrong? What are the safety concerns?
- Does this task produce output you reuse (reports, configs, docs)?
- Do you do this alone or does it involve handoffs to others?

### Round 4: Existing Claude Code usage (if any)

- Do you already use Claude Code? What works well?
- Do you have an existing CLAUDE.md? What's in it?
- Have you tried skills, agents, or commands before?
- What frustrated you about previous setups?

After the interview, summarize what you learned and confirm with the user
before proceeding to Stage 2.

---

## Stage 2: Task Classification

For each task/pain point identified, read `references/classification-engine.md`
and classify it. The classification determines what component (if any) to build.

Present the classification to the user as a table:

```
| Task | Classification | Component | Reasoning |
|------|---------------|-----------|-----------|
| Quick pod check | Vanilla CC | None needed | One command, no special knowledge |
| Incident investigation | Agent + skills | k8s-diagnostician agent + health-check skill | Needs isolation, reads many files, different permissions from normal work |
| Daily standup prep | Command | /morning command | Repeatable sequence, user-invoked |
| K8s naming conventions | CLAUDE.md rule | .claude/rules/k8s-naming.md | Always-on constraint, not a task |
| Cluster health report | Skill with script | health-check skill | Reusable knowledge + deterministic script |
```

Ask the user if they agree or want to adjust before proceeding.

---

## Stage 3: Architecture Design

Based on the classifications, design the workspace.
Read `references/architecture-patterns.md` for the decision framework.

### Step 3.1: Determine complexity tier

| Tier | When | What to build |
|------|------|--------------|
| **Simple** | 1-2 pain points, single domain, no safety concerns | CLAUDE.md + maybe 1-2 skills. No agents. No hooks. |
| **Moderate** | 3-5 pain points, single domain, some safety needs | CLAUDE.md + 2-4 skills + 1-2 agents + basic commands. Maybe a safety hook. |
| **Complex** | 5+ pain points, multiple domains, safety-critical ops, team usage | Full architecture: CLAUDE.md + skills + specialist agents + commands + hooks + skill-eval |

### Step 3.2: Design the component map

For each component you're recommending, specify:

- **What it is** (name, type, role)
- **Why it exists** (which pain point it solves)
- **Where it lives** (global vs project scope, with reasoning)
- **How it connects** (what invokes it, what it invokes)
- **What it does NOT need** (explicitly note what you're leaving out and why)

Present as a visual architecture:

```
WORKSPACE: ~/work/project-name/

Routing:
  /command-a → agent-x → [skill-1, skill-2]
  /command-b → agent-y → [skill-3]
  Freeform → Claude auto-invokes skill-1, skill-2, skill-3

Scope:
  Global agents: [agent-x, agent-y] (need to work from any folder)
  Project skills: [skill-1, skill-2, skill-3] (domain-specific)
  Project commands: [command-a, command-b] (project workflows)
  Global commands: [/morning] (cross-project utility)

Safety:
  PreToolUse hook: blocks [specific dangerous commands]
  Agent tool scoping: agent-x read-only, agent-y full access

NOT building (and why):
  - No skill-eval hook: all routing is via commands, no freeform skill matching needed
  - No Stop hooks: agents return simple output, no verification needed
  - No agent memory: tasks are one-shot, no accumulation benefit
```

Confirm the design with the user before drafting files.

---

## Stage 4: Draft Files

For each component in the approved design, draft the actual file content.
Follow these quality standards:

### For skills
- Description: pushy ONLY if auto-invoked; clear but concise if agent-preloaded
- Body: under 500 lines, progressive disclosure to references/ if needed
- Scripts: self-contained, outputs JSON/structured data
- Include a Gotchas section placeholder: "## Gotchas\n(Add failure patterns as you discover them)"

### For agents
- Prompt: under 80 lines, focused on WHO + HOW + OUTPUT
- Domain knowledge: in preloaded skills, not in the agent prompt
- Tools: scoped to what the agent actually needs
- Model: intentionally chosen (sonnet default, opus for deep reasoning, haiku for quick lookups)
- Safety: explicit rules for any write operations

### For commands
- Thin routers: spawn the right agent, pass $ARGUMENTS
- Utility commands: self-contained, no agent needed
- Description: clear for the /menu

### For CLAUDE.md
- Under 100 lines for a new project (grow as needed)
- Stack, key commands, critical safety rules, directory overview
- Reference external files for details: "For K8s conventions, see .claude/rules/k8s.md"

### For hooks
- Safety: PreToolUse with exit code 2 for blocking
- Only add hooks that are justified by the architecture

Present each file with an explanation of the design decisions.

---

## Stage 5: Installation Guide

After all files are drafted and approved, produce an installation guide:

```bash
# Step 1: Create the directory structure
mkdir -p .claude/{agents,skills,commands,hooks,rules}

# Step 2: Create each file
# (list the exact commands or offer to create them)

# Step 3: Verify
# Run the cc-setup-auditor skill if available
```

Also produce a "What to do next" section:
- How to test the setup
- When to revisit and add more components
- How to evolve from Simple → Moderate → Complex as needs grow

---

## Anti-patterns to watch for

Throughout all stages, actively prevent these:

1. **Over-engineering**: Building full orchestration for a simple project.
   If the user has 2 tasks, they need CLAUDE.md and maybe a skill — not 5 agents.

2. **Template stamping**: Producing the same Command→Agent→Skill pattern
   regardless of whether the user needs it.

3. **Premature optimization**: Building skill-eval hooks before there are
   enough skills to justify the complexity.

4. **God agent**: One agent that does everything. If the user describes
   multiple distinct domains, split into specialists — but only if the
   domains have different permission/model/context needs.

5. **Skill bloat**: Making a skill for every piece of knowledge. Some things
   belong in CLAUDE.md rules (always-on conventions), not skills (on-demand workflows).

6. **Copy-paste architecture**: Recommending what worked for someone else's
   project without adapting to this user's actual needs.

## Reference files

- `references/classification-engine.md` — Decision framework for classifying
  each task into the right component type
- `references/architecture-patterns.md` — Common architecture patterns with
  when to use each one, from simple to complex
