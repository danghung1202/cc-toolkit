#!/bin/bash
# cc-setup-auditor/scripts/discover.sh
# Scans workspace for Claude Code configuration and maps relationships.
# Usage: bash scripts/discover.sh [workspace-root]
# Outputs structured text report (not JSON — easier for Claude to read).

ROOT="${1:-.}"
GLOBAL="$HOME/.claude"

echo "============================================"
echo "  SETUP AUDITOR — WORKSPACE DISCOVERY"
echo "============================================"
echo ""
echo "Workspace: $(cd "$ROOT" && pwd)"
echo "Global:    $GLOBAL"
echo "Date:      $(date)"
echo ""

# --- CLAUDE.md files ---
echo "== CLAUDE.md FILES =="
for loc in "$GLOBAL/CLAUDE.md" "$ROOT/CLAUDE.md" "$ROOT/.claude/CLAUDE.md"; do
  if [ -f "$loc" ]; then
    lines=$(wc -l < "$loc")
    echo "  $loc ($lines lines)"
  fi
done
echo ""

# --- Rules ---
echo "== RULES (.claude/rules/) =="
for d in "$ROOT/.claude/rules" "$GLOBAL/rules"; do
  if [ -d "$d" ]; then
    for f in "$d"/*.md; do
      [ -f "$f" ] || continue
      lines=$(wc -l < "$f")
      has_paths=$(grep -c "^paths:" "$f" 2>/dev/null || echo 0)
      scope=""
      [ "$has_paths" -gt 0 ] && scope=" [path-scoped]"
      echo "  $f ($lines lines)$scope"
    done
  fi
done
echo ""

# --- Skills ---
echo "== SKILLS =="
find "$ROOT" "$GLOBAL" -name "SKILL.md" -not -path "*/node_modules/*" 2>/dev/null | sort | while read -r f; do
  dir=$(dirname "$f")
  dirname=$(basename "$dir")
  lines=$(wc -l < "$f")
  name=$(grep -m1 "^name:" "$f" | sed 's/name:[[:space:]]*//')

  # Check name match
  match="MATCH"
  [ "$dirname" != "$name" ] && match="MISMATCH ($dirname != $name)"

  # Frontmatter flags
  user_inv=$(grep -c "user-invocable:" "$f" 2>/dev/null || echo 0)
  disable_model=$(grep -c "disable-model-invocation:" "$f" 2>/dev/null || echo 0)
  ctx_fork=$(grep -c "context:" "$f" 2>/dev/null || echo 0)

  # Description length
  desc_line=$(grep -m1 "^description:" "$f" 2>/dev/null)
  desc_len=${#desc_line}

  # Subdirectories
  subdirs=""
  [ -d "$dir/scripts" ] && subdirs="${subdirs}scripts "
  [ -d "$dir/references" ] && subdirs="${subdirs}references "
  [ -d "$dir/resources" ] && subdirs="${subdirs}resources "
  [ -d "$dir/assets" ] && subdirs="${subdirs}assets "
  [ -z "$subdirs" ] && subdirs="(none)"

  echo "  $f"
  echo "    name: $name | dir: $dirname | $match"
  echo "    lines: $lines | desc_chars: $desc_len | subdirs: $subdirs"

  flags=""
  [ "$user_inv" -gt 0 ] && flags="${flags}user-invocable "
  [ "$disable_model" -gt 0 ] && flags="${flags}disable-model-invocation "
  [ "$ctx_fork" -gt 0 ] && flags="${flags}context-fork "
  [ -n "$flags" ] && echo "    flags: $flags"
done
echo ""

# --- Agents ---
echo "== AGENTS =="
for d in "$ROOT/.claude/agents" "$GLOBAL/agents"; do
  [ -d "$d" ] || continue
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f")
    name=$(grep -m1 "^name:" "$f" 2>/dev/null | sed 's/name:[[:space:]]*//')
    model=$(grep -m1 "^model:" "$f" 2>/dev/null | sed 's/model:[[:space:]]*//')
    tools=$(grep -m1 "^tools:" "$f" 2>/dev/null | sed 's/tools:[[:space:]]*//')
    perm=$(grep -m1 "^permissionMode:" "$f" 2>/dev/null | sed 's/permissionMode:[[:space:]]*//')
    memory=$(grep -m1 "^memory:" "$f" 2>/dev/null | sed 's/memory:[[:space:]]*//')
    max_turns=$(grep -m1 "^maxTurns:" "$f" 2>/dev/null | sed 's/maxTurns:[[:space:]]*//')

    # Extract preloaded skills
    preloaded_skills=""
    in_skills=0
    while IFS= read -r line; do
      if echo "$line" | grep -q "^skills:"; then
        in_skills=1
        continue
      fi
      if [ "$in_skills" -eq 1 ]; then
        if echo "$line" | grep -q "^  *- "; then
          skill_name=$(echo "$line" | sed 's/^  *- *//')
          preloaded_skills="${preloaded_skills}${skill_name} "
        else
          in_skills=0
        fi
      fi
    done < "$f"

    echo "  $f"
    echo "    name: ${name:-(unnamed)} | model: ${model:-inherit} | lines: $lines"
    [ -n "$tools" ] && echo "    tools: $tools"
    [ -n "$perm" ] && echo "    permissionMode: $perm"
    [ -n "$memory" ] && echo "    memory: $memory"
    [ -n "$max_turns" ] && echo "    maxTurns: $max_turns"
    [ -n "$preloaded_skills" ] && echo "    preloaded_skills: $preloaded_skills"
  done
done
echo ""

# --- Commands ---
echo "== COMMANDS =="
for d in "$ROOT/.claude/commands" "$GLOBAL/commands"; do
  [ -d "$d" ] || continue
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f")
    desc=$(grep -m1 "^description:" "$f" 2>/dev/null | sed 's/description:[[:space:]]*//')

    # Check if command references an agent
    spawns_agent=""
    agent_ref=$(grep -i -m1 "agent\|subagent\|spawn\|Task tool" "$f" 2>/dev/null | head -1)
    [ -n "$agent_ref" ] && spawns_agent="(may route to agent)"

    echo "  $f ($lines lines) $spawns_agent"
    [ -n "$desc" ] && echo "    description: ${desc:0:80}..."
  done
done
echo ""

# --- Hooks ---
echo "== HOOKS =="
settings_file=""
for loc in "$ROOT/.claude/settings.json" "$GLOBAL/settings.json"; do
  if [ -f "$loc" ]; then
    settings_file="$loc"
    echo "  Settings: $loc"

    for event in PreToolUse PostToolUse UserPromptSubmit Stop Notification SessionStart; do
      count=$(grep -c "\"$event\"" "$loc" 2>/dev/null || echo 0)
      [ "$count" -gt 0 ] && echo "    $event: $count hook(s) configured"
    done
    break
  fi
done
[ -z "$settings_file" ] && echo "  No settings.json found"

# Check for hook scripts
if [ -d "$ROOT/.claude/hooks" ]; then
  echo "  Hook scripts:"
  for f in "$ROOT/.claude/hooks"/*; do
    [ -f "$f" ] || continue
    echo "    $(basename "$f")"
  done
fi
echo ""

# --- Relationship map ---
echo "== RELATIONSHIP MAP =="
echo ""
echo "  Command → Agent routing:"
for d in "$ROOT/.claude/commands" "$GLOBAL/commands"; do
  [ -d "$d" ] || continue
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    cmd_name=$(basename "$f" .md)
    # Look for agent references in command body
    agents_mentioned=$(grep -o -i '[a-z_-]*agent[a-z_-]*\|spawn.*[a-z_-]*\|Task.*agent' "$f" 2>/dev/null | head -3)
    if [ -n "$agents_mentioned" ]; then
      echo "    /$cmd_name → $agents_mentioned"
    fi
  done
done
echo ""

echo "  Agent → Skill preloading:"
for d in "$ROOT/.claude/agents" "$GLOBAL/agents"; do
  [ -d "$d" ] || continue
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    agent_name=$(grep -m1 "^name:" "$f" 2>/dev/null | sed 's/name:[[:space:]]*//')
    in_skills=0
    skills_list=""
    while IFS= read -r line; do
      if echo "$line" | grep -q "^skills:"; then
        in_skills=1; continue
      fi
      if [ "$in_skills" -eq 1 ]; then
        if echo "$line" | grep -q "^  *- "; then
          s=$(echo "$line" | sed 's/^  *- *//')
          skills_list="${skills_list}${s}, "
        else
          in_skills=0
        fi
      fi
    done < "$f"
    [ -n "$skills_list" ] && echo "    ${agent_name:-$(basename $f .md)} → [${skills_list%, }]"
  done
done
echo ""

echo "  Skill invocation patterns:"
find "$ROOT" "$GLOBAL" -name "SKILL.md" -not -path "*/node_modules/*" 2>/dev/null | sort | while read -r f; do
  name=$(grep -m1 "^name:" "$f" | sed 's/name:[[:space:]]*//')
  [ -z "$name" ] && continue

  patterns=""

  # Check if any agent preloads this skill
  for d in "$ROOT/.claude/agents" "$GLOBAL/agents"; do
    [ -d "$d" ] || continue
    for af in "$d"/*.md; do
      [ -f "$af" ] || continue
      if grep -q "- $name" "$af" 2>/dev/null; then
        agent_name=$(grep -m1 "^name:" "$af" | sed 's/name:[[:space:]]*//')
        patterns="${patterns}agent-preloaded(${agent_name:-?}), "
      fi
    done
  done

  # Check frontmatter flags
  if grep -q "user-invocable: false" "$f" 2>/dev/null; then
    patterns="${patterns}model-only, "
  elif grep -q "disable-model-invocation: true" "$f" 2>/dev/null; then
    patterns="${patterns}user-only, "
  else
    patterns="${patterns}auto-invocable, "
  fi

  if grep -q "context:.*fork" "$f" 2>/dev/null; then
    patterns="${patterns}fork-isolated, "
  fi

  echo "    $name: [${patterns%, }]"
done
echo ""

# --- Summary ---
echo "== SUMMARY =="
skill_count=$(find "$ROOT" "$GLOBAL" -name "SKILL.md" -not -path "*/node_modules/*" 2>/dev/null | wc -l)
agent_count=0
for d in "$ROOT/.claude/agents" "$GLOBAL/agents"; do
  [ -d "$d" ] && agent_count=$((agent_count + $(ls "$d"/*.md 2>/dev/null | wc -l)))
done
cmd_count=0
for d in "$ROOT/.claude/commands" "$GLOBAL/commands"; do
  [ -d "$d" ] && cmd_count=$((cmd_count + $(ls "$d"/*.md 2>/dev/null | wc -l)))
done

echo "  Skills: $skill_count | Agents: $agent_count | Commands: $cmd_count"
if [ "$skill_count" -le 2 ] && [ "$agent_count" -le 1 ]; then
  echo "  Complexity tier: SIMPLE"
elif [ "$skill_count" -le 6 ] && [ "$agent_count" -le 3 ]; then
  echo "  Complexity tier: MODERATE"
else
  echo "  Complexity tier: COMPLEX"
fi
echo ""
echo "============================================"
echo "  Discovery complete. Proceed to Phase 2."
echo "============================================"
