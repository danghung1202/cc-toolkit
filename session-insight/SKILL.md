---
name: session-insight
description: Collect and analyze agent/skill invocation data across sessions. Use this skill whenever the user wants to track which agents and skills were used in a session, review invocation patterns, generate usage reports, or analyze skill compliance rates. Supports two modes — "collect" to record the current session's invocations, and "report" to generate usage summaries over a time period. Trigger this skill when the user says things like "capture session insight", "track what was used", "show me agent usage", "skill report", or "monthly usage summary".
user-invocable: true
---

# Session Insight

Track agent and skill invocations across sessions to understand usage patterns and skill compliance over time.

## Modes

This skill operates in two modes based on user intent:

| User says | Mode |
|---|---|
| `/session-insight` (no args, or "collect") | **Collect** — scan current session, append to data file |
| `/session-insight report` or "show usage", "monthly report" | **Report** — read data file, generate summary |
| `/session-insight report 2026-Q1` or "last month" | **Report** — filtered by time period |

## Data File

**Location:** `C:/Users/hung.dang/.claude/session-insights.json`

This is the single source of truth — an append-only JSON file that grows across sessions and projects.

### Schema

```json
{
  "sessions": [
    {
      "date": "2026-03-27",
      "project": "C:/Data/K8s",
      "session_name": "short session name or title",
      "duration_estimate": "short|medium|long",
      "invocations": [
        {
          "user_prompt": "the actual words the user typed that triggered this chain",
          "entry_point": "k8s-leader or direct skill invocation",
          "agent": "cluster-admin",
          "skill": "cluster-user",
          "task": "Generate Kubeconfig for Existing SA",
          "followed_skill": true,
          "notes": "optional — explain why followed_skill is false, or anything notable"
        }
      ]
    }
  ]
}
```

### Field Definitions

| Field | Required | Description |
|---|---|---|
| `date` | yes | Session date (YYYY-MM-DD) |
| `project` | yes | Working directory path — identifies which project |
| `session_name` | yes | Short description of the session's main topic |
| `duration_estimate` | no | Rough session length: short (<30min), medium (30-90min), long (>90min) |
| `invocations[]` | yes | Array of agent/skill invocations (can be empty if no agents were used) |
| `.user_prompt` | yes | The actual user message that triggered this invocation chain |
| `.entry_point` | yes | What received the request first — a command like `k8s-leader`, or `direct` for direct skill/agent calls |
| `.agent` | no | Agent that was spawned (omit if skill was invoked directly without an agent) |
| `.skill` | no | Skill that was used by the agent (omit if agent handled without a skill) |
| `.task` | no | Specific task within the skill (e.g., "Generate Kubeconfig for Existing SA") |
| `.followed_skill` | yes (when skill is present) | Whether the agent followed the skill's defined steps. `true` = steps followed, `false` = agent improvised or used general knowledge |
| `.notes` | no | Context for why `followed_skill` is false, or other notable observations |

## Mode: Collect

Scan the current conversation and extract all agent/skill invocations.

### Steps

1. **Read the data file** — if `session-insights.json` exists, read it. If not, initialize with `{"sessions": []}`.

2. **Scan the conversation** — look for:
   - Agent tool calls (identifies which agents were spawned)
   - Skill tool calls (identifies direct skill invocations)
   - The user message that preceded each invocation (the trigger prompt)
   - Whether the agent followed its skill's defined workflow or improvised
   - Any corrections the user made about wrong routing or skill non-compliance

3. **Build the session entry** — construct the JSON object following the schema above. For each invocation:
   - Quote the user's actual words in `user_prompt` (abbreviated if very long, but keep the intent clear)
   - Trace the routing chain: user prompt → entry_point → agent → skill → task
   - Assess `followed_skill` by checking if the agent used the skill's defined commands/scripts/paths vs improvised its own approach
   - Add `notes` only when there's something worth recording (skill ignored, wrong routing, notable workaround)

4. **Present the entry for review** — show the user what will be appended. They may correct routing chains or `followed_skill` assessments.

5. **Append and save** — add the session entry to the `sessions` array and write the file. Do not overwrite existing sessions.

### Assessing `followed_skill`

This is a judgment call. Guidelines:

| Signal | `followed_skill` |
|---|---|
| Agent used the script/command defined in the skill | `true` |
| Agent saved output to the skill's defined path | `true` |
| Agent followed the skill's step sequence | `true` |
| Agent used general knowledge instead of skill-defined steps | `false` |
| Agent used a different script/command than what the skill defines | `false` |
| Agent saved output to a non-standard path | `false` |
| No skill was involved (agent handled directly) | omit the field |

When `followed_skill` is `false`, always add a `notes` explaining what happened — this is the most valuable data for improving skills.

## Mode: Report

Generate a usage summary from the accumulated data.

### Steps

1. **Read the data file** — load `session-insights.json`.

2. **Determine time period** — based on user input:
   - No period specified → last 30 days
   - "Q1", "Q2", etc. → that quarter of the current year
   - "2026-Q1" → specific quarter
   - "last month" → previous calendar month
   - "march", "2026-03" → specific month
   - "all" → everything

3. **Generate the report** — compute and display:

```markdown
# Session Insight Report: [period]

## Summary
- **Sessions:** [count]
- **Total invocations:** [count]
- **Unique agents used:** [count]
- **Unique skills used:** [count]
- **Skill compliance rate:** [followed / total with skills]%

## Agent Usage
| Agent | Invocations | % of Total |
|---|---|---|
| cluster-admin | 28 | 32% |
| k8s-ops | 22 | 25% |
| ... | ... | ... |

## Skill Usage
| Skill | Invocations | Followed | Ignored | Compliance |
|---|---|---|---|---|
| cluster-user | 16 | 14 | 2 | 88% |
| k8s-debug | 14 | 14 | 0 | 100% |
| ... | ... | ... | ... | ... |

## Skill Compliance Issues
| Date | Session | Skill | What Happened |
|---|---|---|---|
| 2026-03-27 | Agents ignore skills | cluster-user | Agent hand-rolled kubeconfig instead of using generate-team-kubeconfig.sh |

## Entry Point Distribution
| Entry Point | Count | % |
|---|---|---|
| k8s-leader | 35 | 60% |
| direct | 15 | 26% |
| ... | ... | ... |

## Project Distribution
| Project | Sessions | Invocations |
|---|---|---|
| C:/Data/K8s | 18 | 42 |
| ... | ... | ... |
```

4. **Save the report** — write to the workspace as `session-insight-report-[period].md`. Also display inline in the conversation.

5. **Highlight actionable findings** — after the report, call out:
   - Skills with low compliance rates (candidates for stronger execution rules or inlining)
   - Agents that are rarely used (maybe routing isn't reaching them)
   - Skills that are never invoked (maybe description needs improvement)
   - Entry points that dominate (good) vs direct calls that bypass routing (potential gap)
