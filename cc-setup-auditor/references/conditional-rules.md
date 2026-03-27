# Conditional Rules

Every rule has a **precondition** — a condition from the Phase 1 architecture
comprehension that must be true for the rule to apply. If the precondition
is not met, SKIP the rule and note why.

Rules are organized by domain but evaluated per-component using the
relationship map, role classification, and invocation patterns from Phase 1.

---

## A. Skill Rules

### A1. Structure rules (apply to ALL skills)

These are mechanical checks that always apply regardless of context.

| ID | Check | Pass criteria | Failure impact |
|----|-------|---------------|----------------|
| A1.1 | Dir name = `name:` field | Exact match, case-sensitive | CRITICAL: skill silently won't load |
| A1.2 | File named exactly `SKILL.md` | Case-sensitive | CRITICAL: won't be discovered |
| A1.3 | Only standard subdirectories | `scripts/`, `references/`, `assets/` | MEDIUM: non-standard names may confuse |
| A1.4 | `name:` format valid | Lowercase, numbers, hyphens. Max 64 chars. No start/end hyphen | CRITICAL: may not load |
| A1.5 | `description:` present and non-empty | Required field | CRITICAL: skill can't trigger |
| A1.6 | `description:` under 1024 chars | Spec limit | HIGH: may be truncated |
| A1.7 | No `<` or `>` in description | Can inject into system prompt | HIGH: security risk |

### A2. Description quality (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| A2.1 | Description is "pushy" with trigger phrases | Skill is auto-invoked (Claude matches description to freeform prompts) | Skill is ONLY agent-preloaded (`user-invocable: false` or exclusively listed in agent `skills:` fields) — description is never used for triggering |
| A2.2 | Description includes WHAT + WHEN | Skill is auto-invoked or user-invoked | Skill is only agent-preloaded — agent decides when, not description matching |
| A2.3 | Description lists specific keywords users would type | Skill is auto-invoked | Skill is user-invoked only (user knows the /name) or agent-preloaded |
| A2.4 | Description covers edge cases ("even if they don't say X") | Skill is auto-invoked AND handles tasks that overlap with other skills | Skill has a unique, non-overlapping domain |

**Why this matters**: A skill preloaded via an agent's `skills:` field gets its full SKILL.md body injected at agent startup. The description is never consulted for triggering. Making the description "pushy" is wasted effort — and worse, if the same skill is also auto-discoverable, an overly broad description could cause it to trigger in the wrong contexts.

### A3. Content quality (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| A3.1 | SKILL.md under 500 lines | Skill has 2+ distinct sub-topics that COULD be split into references | Skill is a single focused domain under 300 lines — splitting would add complexity without benefit |
| A3.2 | Uses progressive disclosure (routes to references) | Skill is >200 lines AND has sub-topics | Skill is a simple context-loader or knowledge skill under 200 lines |
| A3.3 | Scripts run via bash, code doesn't enter context | Skill has scripts/ directory | No scripts |
| A3.4 | References loaded on demand with clear triggers | Skill has references/ directory | No references |
| A3.5 | Has a "Gotchas" section | Skill has been used in production and failure patterns are known | New skill, no failure history yet |
| A3.6 | Doesn't state the obvious | Skill contains instructions Claude would follow without being told | Skill covers genuinely non-obvious domain knowledge |
| A3.7 | Gives goals + constraints, not prescriptive step-by-step | Skill role is `knowledge` or `diagnostic` — Claude should reason | Skill role is `workflow` with safety-critical steps that MUST be followed exactly (e.g., database migrations) |
| A3.8 | Uses imperative form | Always a good practice | N/A — always apply but LOW priority |
| A3.9 | Explains WHY not just WHAT | Rules exist that Claude might not understand the reasoning for | Rules are self-evident |
| A3.10 | Uses `` !`command` `` for dynamic context | Skill needs live system state at invocation time (e.g., current cluster status, git branch) | Skill is purely reference material that doesn't depend on runtime state |
| A3.11 | Includes input/output examples | Skill has a specific output format requirement | Skill is open-ended guidance |
| A3.12 | Skill content correctly classified as horizontal vs vertical | Always — apply to every skill | N/A — always apply |
| A3.13 | Workflow skills use imperative script/command references | Skill role is `workflow` AND defines specific scripts or commands | Skill role is `knowledge` or `diagnostic` |

**A3.12 — Horizontal vs Vertical classification:**

Every skill's content falls into two categories:
- **Horizontal** = conventions, patterns, naming rules, architecture context — knowledge the agent needs on *every task*. This belongs in CLAUDE.md or the agent prompt, not in skills. When packed in a skill, it competes with the agent's training knowledge and often loses (the agent "already knows" the answer and skips reading the skill).
- **Vertical** = step-by-step workflows with specific scripts, paths, and commands. This belongs in skills because it defines the *approved procedure* for this workspace.

If a skill mixes both, recommend splitting: extract horizontal content to CLAUDE.md, keep vertical steps in the skill.

Recommendation depends on invocation pattern:
- **Agent-preloaded skill with horizontal content** → move conventions to CLAUDE.md or agent prompt; keep only vertical workflow in skill
- **Auto-invoked/standalone skill with horizontal content** → move to CLAUDE.md if needed on every task; flag that the skill may be undertriggered since the agent may use training knowledge instead
- **Skill that is purely horizontal** → candidate for migration to CLAUDE.md entirely

Source: Vercel research — AGENTS.md (persistent context) achieved 100% pass rate vs skills' 53% for horizontal knowledge. Skills went unused in 56% of cases even when available. See: https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals

**A3.13 — Imperative script references:**

Workflow skills that define specific scripts or commands should reference them imperatively (e.g., "Run `generate-team-kubeconfig.sh`") rather than describing the goal generically (e.g., "generate a kubeconfig"). Generic descriptions are easily overridden by the agent's training knowledge — the agent pattern-matches "generate kubeconfig" to its training data and hand-rolls the solution instead of using the defined script.

### A4. Isolation and context (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| A4.1 | Should use `context: fork` | Skill produces verbose output (reads many files, long script output) AND is NOT already preloaded into an agent (which already provides isolation) | Skill is lightweight OR already runs inside an agent's isolated context |
| A4.2 | Skill preload count per agent is manageable | Agent has `skills:` field with 3+ skills listed | Agent preloads 1-2 skills — reasonable |
| A4.3 | Total preloaded skill lines per agent under 1500 | Agent preloads multiple skills | Agent preloads a single small skill |

**Key insight**: When a skill is listed in an agent's `skills:` frontmatter, the ENTIRE
SKILL.md body is injected into the agent's context at startup — not on-demand. So progressive
disclosure within the skill (references loaded later) still works, but the main SKILL.md body
is a fixed cost. 3 skills × 400 lines = 1,200 lines of context before the agent reads its first file.

### A5. Scope (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| A5.1 | Specialist skill is in project scope | Skill is domain-specific (k8s, sonar, etc.) AND project has .claude/skills/ | Single-project workspace where scope doesn't matter |
| A5.2 | General skill is global | Skill is used across projects (postmortem-writer, blog-writer) | Skill is project-specific |
| A5.3 | Global agent can reach project skill | Global agent references a project skill via file path (Layer 2 pattern) | Agent is also project-scoped OR skill is global |

---

## B. Agent Rules

### B1. Should this be an agent at all? (apply to EVERY agent)

Before checking agent quality, verify it SHOULD be an agent.

| ID | Check | Signals it SHOULD be an agent | Signals it should be a SKILL instead |
|----|-------|-------------------------------|--------------------------------------|
| B1.1 | Needs own context window? | Explores many files, verbose output, research tasks | Lightweight, result is compact |
| B1.2 | Needs different permissions? | Read-only diagnostics vs full write access | Same permissions as main session |
| B1.3 | Needs different model? | Opus for deep reasoning, Haiku for quick lookups | Same model is fine |
| B1.4 | Tasks can run in parallel? | Multiple investigations simultaneously | Sequential is fine |
| B1.5 | Needs persistent memory? | Accumulates knowledge across sessions | Stateless is fine |
| B1.6 | Would output pollute main context? | Reading 50+ files, long logs | Result is a short answer |

**If 4+ answers are "should be skill"** → recommend converting to a skill.
But check the architecture first — if it's part of a Command→Agent→Skill chain,
the agent may exist for routing purposes even if the work is simple.

### B2. Agent quality (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| B2.1 | Prompt body under 80 lines | Agent has a corresponding skill that could hold the domain knowledge | Agent is standalone with no skills, knowledge must be in the prompt |
| B2.2 | Prompt focuses on WHO + HOW + OUTPUT | Agent has preloaded skills for WHAT to know | Agent has no skills — prompt must contain both behavior and knowledge |
| B2.3 | Domain knowledge in skills, not prompt | Agent preloads skills | Agent is a simple reviewer/researcher with inline instructions — skill extraction would be over-engineering |
| B2.4 | Output format specified | Agent returns results to main context or another system | Agent is interactive / conversational |
| B2.5 | Safety rules explicit | Agent role is `operator` or has write permissions | Agent role is `diagnostician` or `researcher` with read-only tools — safety rules are implicit in the tool restriction |
| B2.6 | Model intentionally chosen | Architecture has agents with different roles that benefit from different models | All agents do similar-complexity work — same model is fine |
| B2.7 | Uses persistent memory | Agent role involves pattern accumulation (incident investigation, code review trends) | Agent does one-shot tasks with no learning benefit |

### B3. Tool scoping (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| B3.1 | `tools:` field restricts to needed tools | Agent has `operator` role or runs commands that could be destructive | Agent is purely read-only (researcher, reviewer) AND the default tool set is acceptable |
| B3.2 | Tools use wildcards appropriately | Agent needs a subset of Bash commands (e.g., `Bash(kubectl get*)`) | Agent needs broad Bash access for varied work |
| B3.3 | `disallowedTools:` set for dangerous tools | Agent has broad `tools:` but specific operations are forbidden | Agent's `tools:` allowlist already excludes dangerous tools |

### B4. Specialist vs generalist (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| B4.1 | One domain per agent | Agent covers 2+ distinct domains AND those domains have different permission/model needs | Agent covers related sub-domains that naturally share tools and context |
| B4.2 | Different permissions justify separation | Two operations on the same system need different safety levels (diagnose vs modify) | All operations need the same permission level |
| B4.3 | Skill preloading is lean per agent | Multiple specialist agents each load only their domain skills | Single generalist loads all skills — check if total preloaded lines cause context pressure |
| B4.4 | Commands provide deterministic routing | Complexity tier is Moderate or Complex with multiple agents | Simple tier with 1 agent — routing is implicit |

### B5. Layer pattern (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| B5.1 | Layer 1 baked into agent prompt | Agent is global AND needs to work from any directory | Agent is project-scoped and always runs from the right folder |
| B5.2 | Layer 2 file paths in agent prompt | Agent references project files that aren't always in the current directory | Agent only works with files in its current directory |
| B5.3 | Agent degrades gracefully without Layer 3 | Agent is global and may run outside the project folder | Agent is project-scoped — Layer 3 always loads |

### B6. Skill execution enforcement (conditional)

Agents with pre-loaded skills often ignore the skill's defined steps and use general training knowledge instead. This is the "pre-training overrides retrieval" problem — the agent "already knows" how to do the task and skips the approved workflow sitting in its context.

Source: Vercel found skills went unused 56% of the time. Our own testing confirmed that even when skill content is injected into agent context via `skills:` frontmatter, agents still default to training knowledge. See: https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| B6.1 | Agent has explicit Skill Execution Rule section | Agent preloads skills via `skills:` field | Agent has no preloaded skills |
| B6.2 | Execution rule states skill instructions override general knowledge | B6.1 applies AND skills define specific scripts, paths, or commands | Skills are pure knowledge/reference with no prescribed steps |
| B6.3 | Agent specifies fallback behavior for unmatched tasks | Agent has a skill routing table | Agent handles a single domain with a single skill |

**What a good Skill Execution Rule looks like:**

```markdown
## Skill Execution Rule

When a task matches a skill listed in the routing table above, your pre-loaded
skill content defines the approved workflow for this workspace. Follow its steps,
commands, and scripts exactly — your general knowledge about how to accomplish
the same task is secondary.

If no skill matches the task, handle it using your own knowledge but report back
to the leader that no skill covered this task.
```

**Key phrase:** "your general knowledge is secondary" — this directly addresses the pre-training vs retrieval priority that causes agents to ignore pre-loaded skills.

**B6.1 failure impact:** HIGH — without this rule, agents with pre-loaded workflow skills will intermittently ignore defined scripts, output paths, and conventions. The failure is silent (the task appears to succeed) and inconsistent (depends on whether the agent's training knowledge covers the task).

---

## C. Command Rules

### C1. Command quality (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| C1.1 | Command is a thin router | Command's role is `router` — spawns an agent | Command's role is `utility` (standalone action) or `workflow` (multi-step in main context) |
| C1.2 | Command doesn't duplicate agent prompt | Command routes to an agent that has its own prompt | Command IS the workflow — no agent involved |
| C1.3 | Deterministic routing | Command always spawns the same agent | Command makes dynamic decisions (acceptable for orchestrator commands) |
| C1.4 | Arguments passed through | Command receives $ARGUMENTS and forwards to agent | Command needs no arguments |
| C1.5 | `description:` in frontmatter | Always — shown in /command menu | N/A — always apply |

### C2. Scope (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| C2.1 | Project commands in project scope | Command is domain-specific | Single-project workspace |
| C2.2 | General commands global | Command is cross-project (morning, handoff) | Command is tied to specific project |
| C2.3 | /command menu not cluttered | >7 global commands | <7 global commands — manageable |

---

## D. Hooks Rules

### D1. Safety coverage (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| D1.1 | PreToolUse safety hook exists | ANY agent or skill can run destructive commands (delete, drain, drop) | ALL agents have tools scoped to read-only — destructive commands are impossible |
| D1.2 | Safety hook uses PreToolUse, not UserPromptSubmit | Safety hook exists | No safety hook needed (all tools read-only) |
| D1.3 | Safety hook covers agent path | Command→Agent→Skill pattern exists (agents run tools without user prompt) | Only freeform prompts exist (no agents) |
| D1.4 | Exit code 2 for blocking | PreToolUse hook blocks commands | Hook only logs, doesn't block |

### D2. Skill evaluation (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| D2.1 | UserPromptSubmit skill-eval hook exists | Skills are auto-invoked from freeform prompts (not all routing is via commands) | ALL skills are exclusively agent-preloaded or command-invoked — freeform triggering isn't used |
| D2.2 | skill-rules.json has entries for auto-invoked skills | Skill-eval hook exists | No skill-eval hook |
| D2.3 | Confidence scoring with weighted triggers | skill-rules.json exists | No skill-eval system |

### D3. Quality and monitoring (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| D3.1 | Stop hook verifies output quality | Agents return important findings (diagnostics, reviews) | Agents do simple tasks where verification adds no value |
| D3.2 | PostToolUse tracks tool usage | Complexity tier is Moderate or Complex | Simple tier — tracking overhead not worth it |
| D3.3 | PreToolUse measures skill activation | Auto-invoked skills exist AND you want data on triggering accuracy | All skills are deterministically routed |

### D4. Agent-scoped hooks (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| D4.1 | Safety-critical agents have own hooks | Agent role is `operator` with write access AND global hooks don't cover its specific danger patterns | Global PreToolUse hook already covers the relevant commands |
| D4.2 | Agent hooks don't duplicate global hooks | Agent has hooks AND global hooks exist | Agent has no hooks |

---

## E. CLAUDE.md Rules

### E1. Content (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| E1.1 | Under 200 lines | Always good practice | N/A — always apply |
| E1.2 | Passes "run the tests" litmus | CLAUDE.md exists at project level | No project CLAUDE.md (global only) |
| E1.3 | No inlined file content | CLAUDE.md references external files | CLAUDE.md is short and self-contained |
| E1.4 | Uses `<important if="...">` tags | CLAUDE.md is over 100 lines AND has domain-specific rules that get ignored | CLAUDE.md is short — all content gets attention |
| E1.5 | Doesn't duplicate agent Layer 1 content | Agents exist with baked-in essential facts | No agents — CLAUDE.md is the only context source |
| E1.6 | Doesn't duplicate skill content | Skills exist that cover the same knowledge | No skills — CLAUDE.md is the only knowledge source |
| E1.7 | Horizontal knowledge lives in CLAUDE.md, not buried in skills | Skills exist that contain conventions, patterns, or architecture context the agent needs on every task | All skills are pure vertical workflows (step-by-step procedures) |

**E1.7 — Why this matters:**

Horizontal knowledge (naming conventions, architecture context, repo structure, deployment patterns) that lives inside skills is effectively "gated" — the agent must choose to consult the skill, or the skill must be pre-loaded and the agent must prioritize it over training knowledge. Both paths have high failure rates (56% unused for external skills, intermittent ignoring for pre-loaded skills).

Moving horizontal knowledge to CLAUDE.md makes it persistent context on every turn with zero decision points. Vercel's research showed this achieves 100% pass rate vs 53% for the same knowledge packaged as skills.

**How to check:** For each skill, ask: "Would an agent need this information even when NOT executing this specific workflow?" If yes, it's horizontal and belongs in CLAUDE.md.

### E2. Scope (conditional)

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| E2.1 | Global = personal profile + universal rules | Global CLAUDE.md exists | No global CLAUDE.md |
| E2.2 | Project = project-specific details | Project CLAUDE.md exists | No project CLAUDE.md |
| E2.3 | .claude/rules/ used for modular instructions | CLAUDE.md is approaching 200 lines AND has distinct topic sections | CLAUDE.md is under 100 lines — splitting adds complexity without benefit |

---

## F. Architecture-Level Rules

These apply to the OVERALL design, not individual components.
Evaluate these AFTER all individual components.

### F1. Orchestration coherence

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| F1.1 | Over-engineering check | Complexity tier is Simple BUT full Command→Agent→Skill orchestration exists | Complexity tier is Moderate or Complex — orchestration is justified |
| F1.2 | Under-engineering check | Complexity tier is Complex BUT no agent isolation or hook safety | Complexity tier is Simple — minimal setup is appropriate |
| F1.3 | No double invocation risk | Both command-routing AND skill-eval hook exist for the same skill | Skill is used by only one invocation pattern |
| F1.4 | Scope alignment | Global agents reference project-scoped skills | All components are in the same scope |
| F1.5 | Context budget reasonable | Sum of: CLAUDE.md lines + preloaded skill lines per agent + rules lines | Each component is individually small |

### F2. Coverage completeness

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| F2.1 | All skills have at least one invocation path | Skills exist | No skills |
| F2.2 | All agents are reachable via command or freeform | Agents exist | No agents |
| F2.3 | Safety hooks cover ALL tool-use paths | Destructive commands are possible | Everything is read-only |
| F2.4 | Freeform fallback exists for common tasks | Commands exist for structured routing | No commands — everything is freeform (acceptable for Simple tier) |

### F3. Pragmatic fit

| ID | Check | Precondition — apply ONLY when | Skip when |
|----|-------|-------------------------------|-----------|
| F3.1 | Vanilla CC tasks stay vanilla | Architecture has orchestration AND some tasks are trivially simple | No orchestration — everything is already vanilla |
| F3.2 | Compaction strategy exists | Complexity tier is Moderate or Complex with long sessions expected | Simple tier with short sessions |
| F3.3 | Model splitting by phase considered | Both planning and execution happen in the same workflow | Workflow is execution-only or planning-only |
