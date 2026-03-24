# Classification Engine

For each task or pain point the user describes, run it through this decision
tree to determine what component (if any) to build.

---

## Decision Tree

Start at the top. Follow the first matching path.

```
Is this a constraint that should ALWAYS apply?
(naming conventions, safety rules, code style, forbidden patterns)
  → YES: CLAUDE.md rule or .claude/rules/ file
  → NO: continue

Is this something Claude already does well without any help?
(basic questions, simple file edits, standard git operations)
  → YES: Nothing. Vanilla Claude Code.
  → NO: continue

Is this a simple, repeatable sequence you invoke by name?
(daily routine, commit workflow, PR creation)
  → YES: Does it need to spawn an agent for isolation?
    → YES: Command (thin router to agent)
    → NO: Command (self-contained workflow)
  → NO: continue

Is this domain knowledge Claude needs to do work correctly?
(API conventions, testing patterns, framework-specific patterns)
  → YES: Does it involve running scripts for deterministic checks?
    → YES: Skill with scripts/ directory
    → NO: Does it have sub-topics worth splitting?
      → YES: Skill with references/ directory
      → NO: Simple skill (SKILL.md only)
  → NO: continue

Is this a task that produces verbose output or needs isolation?
(investigating incidents, reading many files, deep research)
  → YES: Does it need different permissions from normal work?
    → YES: Agent with scoped tools
    → NO: Does it need a different model for quality?
      → YES: Agent with specific model
      → NO: Could a skill with context: fork achieve the same isolation?
        → YES: Skill with context: fork
        → NO: Agent (for explicit lifecycle control)
  → NO: continue

Is this a dangerous operation that needs a safety gate?
(destructive commands, production deployments, data deletion)
  → YES: PreToolUse hook (blocks the operation, fires on ALL paths)
  → NO: continue

Does Claude need to be nudged to use certain skills for certain prompts?
(freeform prompts where the user doesn't invoke a specific command)
  → YES: Are there enough auto-invocable skills (3+) to justify the system?
    → YES: UserPromptSubmit skill-eval hook + skill-rules.json
    → NO: Just make the skill descriptions pushy enough
  → NO: Nothing needed for this
```

---

## Classification outcomes

| Classification | Component | When to use | Token cost |
|---------------|-----------|-------------|-----------|
| **Vanilla CC** | None | Claude handles it fine without help | Zero |
| **CLAUDE.md rule** | CLAUDE.md line or .claude/rules/*.md | Always-on constraint, convention, or safety rule | Loaded every session (~tokens per line) |
| **Utility command** | .claude/commands/*.md | Repeatable action, user-invoked, self-contained | Zero until invoked |
| **Router command** | .claude/commands/*.md | Entry point that spawns a specific agent | Zero until invoked |
| **Simple skill** | .claude/skills/*/SKILL.md | Domain knowledge, no scripts, under 200 lines | ~100 tokens at startup (name+desc), full body when triggered |
| **Rich skill** | .claude/skills/*/ with references/ and/or scripts/ | Complex domain with sub-topics or deterministic automation | Same as simple + references loaded on demand |
| **Forked skill** | Skill with `context: fork` | Heavy exploration that would pollute main context | Runs in isolated context, returns summary |
| **Specialist agent** | .claude/agents/*.md | Needs isolation, different tools, or different model | Own context window |
| **Safety hook** | PreToolUse in settings.json | Block dangerous operations across ALL invocation paths | Runs on every tool use (keep fast, <5s) |
| **Skill-eval hook** | UserPromptSubmit + skill-rules.json | Auto-suggest skills for freeform prompts | Runs on every user prompt (keep fast, <5s) |
| **Quality hook** | Stop in settings.json | Verify output before agent returns to main context | Runs when agent finishes |

---

## Edge cases and judgment calls

### "Should this be a skill or a CLAUDE.md rule?"

| Put in CLAUDE.md when... | Put in a skill when... |
|--------------------------|------------------------|
| It applies to EVERY task (naming conventions, safety) | It applies only to SPECIFIC tasks (testing, deployment) |
| It's a constraint (don't do X) | It's a workflow (how to do X) |
| It's under 10 lines | It's over 10 lines |
| Removing it would cause mistakes on basic tasks | Removing it only affects specialized tasks |
| It's about this project specifically | It's reusable across projects |

### "Should this be a skill or an agent?"

| Use a skill when... | Use an agent when... |
|---------------------|---------------------|
| Result is compact, fits in main context | Result is verbose, would pollute context |
| Same tools/model as main session | Needs different tools or model |
| No parallelism needed | Could run in parallel with other work |
| Knowledge Claude applies while working | Self-contained task Claude delegates |
| You want it portable (works in claude.ai too) | You only need it in Claude Code |

### "Should this be a command or just a skill?"

| Use a command when... | Skill alone is fine when... |
|----------------------|---------------------------|
| User always invokes explicitly by name | Claude should auto-detect when to use it |
| It starts a multi-step workflow | It provides knowledge, not a workflow |
| It needs to spawn an agent | It runs in the main context |
| You want it in the /menu for discoverability | You want Claude to find it by description matching |
| It's a "verb" (do-this, run-that, check-this) | It's a "noun" (conventions, patterns, knowledge) |

### "Do I need a hook for this?"

| Yes, build a hook when... | No hook needed when... |
|--------------------------|----------------------|
| Operation is destructive and MUST be blocked (not just warned) | Agent's `tools:` scoping already prevents it |
| You need automation on EVERY tool use (formatting, logging) | Occasional manual action is fine |
| Skill-eval system is justified (3+ auto-invocable skills) | Descriptions + commands handle routing |
| Quality gate needed before agent output is trusted | Output is reviewed by user anyway |

### "Should I split into multiple agents?"

| Split when... | Keep as one when... |
|--------------|-------------------|
| Different domains need different permission levels | All operations need the same tools |
| Different tasks benefit from different models | Same model quality is fine for all |
| Each specialist preloads only 1-2 relevant skills | Total skill preload is under 500 lines |
| Commands already provide routing to each specialist | You're early in building — start simple, split later |
| Persistent memory helps some agents but not others | No agent needs memory |

---

## Complexity escalation guide

Start simple. Only add complexity when a specific pain point demands it.

```
Phase 1 (Day 1):
  CLAUDE.md (project stack, key commands, safety rules)
  → Test: "run the tests" works first try

Phase 2 (Week 1):
  Add 1-2 skills for your most repeated workflows
  → Test: skill triggers when you need it

Phase 3 (Week 2-3):
  Add agents IF you hit context pollution or need isolation
  Add commands for workflows you invoke 3+ times per day
  → Test: /command does the right thing consistently

Phase 4 (Month 2+):
  Add hooks IF you need safety gates or skill-eval
  Add specialist agents IF single agent is too broad
  Add references/ to skills IF SKILL.md exceeds 300 lines
  → Test: run cc-setup-auditor to validate the architecture
```

Don't skip to Phase 4 on day 1. Most of the value comes from Phase 1-2.
