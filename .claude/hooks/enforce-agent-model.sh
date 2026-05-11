#!/usr/bin/env bash
# Enforces correct model usage for Task tool based on agent definitions
# Blocks Task calls that don't specify the correct model for the subagent_type

# Read tool input from stdin
INPUT=$(cat)

# Extract subagent_type and model from the input
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.subagent_type // empty')
MODEL=$(echo "$INPUT" | jq -r '.model // empty')

# If no subagent_type, allow (not an agent call)
if [[ -z "$SUBAGENT_TYPE" ]]; then
  exit 0
fi

# Get expected model for agent type
# Most agents use sonnet, quality-reviewer uses opus
get_expected_model() {
  case "$1" in
    # Custom project agents
    feature-agent|first-frontend-agent|platform-agent|quality-agent)
      echo "sonnet"
      ;;
    # Role agents
    developer|technical-writer|debugger)
      echo "sonnet"
      ;;
    quality-reviewer)
      echo "opus"
      ;;
    # Built-in agents - default to sonnet for cost efficiency
    Explore|Plan|Bash|general-purpose)
      echo "sonnet"
      ;;
    *)
      # Unknown agent, no enforcement
      echo ""
      ;;
  esac
}

EXPECTED_MODEL=$(get_expected_model "$SUBAGENT_TYPE")

# If agent not in mapping, allow (unknown agent type)
if [[ -z "$EXPECTED_MODEL" ]]; then
  exit 0
fi

# Check if model matches expected
if [[ "$MODEL" != "$EXPECTED_MODEL" ]]; then
  echo "BLOCKED: Agent '$SUBAGENT_TYPE' requires model: '$EXPECTED_MODEL' but got '${MODEL:-<not specified>}'."
  echo "Retry with: model: \"$EXPECTED_MODEL\""
  exit 1
fi

# Model matches, allow the call
exit 0
