#!/usr/bin/env bash
# Cortex installer — cognitive loop for Claude Code.
set -euo pipefail

CTX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HELPERS="$CLAUDE_DIR/helpers"
SKILLS="$CLAUDE_DIR/skills"
CONFIG="$CLAUDE_DIR/config"
BIN_DIR="${HOME}/.local/bin"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
COLLECTION="${CORTEX_COLLECTION:-reflexions}"
DIM="${CORTEX_DIM:-384}"

mkdir -p "$HELPERS" "$SKILLS/speak" "$CONFIG" "$BIN_DIR" "$CLAUDE_DIR/memory"

GREEN="\033[0;32m"; BLUE="\033[0;34m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; NC="\033[0m"

echo -e "${BLUE}⬡ Cortex installer${NC}"

# 1. Qdrant check
if ! curl -sf "$QDRANT_URL/healthz" &>/dev/null; then
    echo -e "${RED}❌ Qdrant not reachable at $QDRANT_URL${NC}"
    echo "   Start it: docker run -d --name qdrant -p 6333:6333 qdrant/qdrant"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Qdrant up at $QDRANT_URL"

# 2. Copy scripts
for f in erl.sh expel.sh reflexion.sh routing-check-hook.sh longmemeval.sh; do
    cp "$CTX_DIR/src/$f" "$HELPERS/$f"
    chmod +x "$HELPERS/$f"
    echo -e "  ${GREEN}✓${NC} $f → $HELPERS/"
done
cp "$CTX_DIR/src/vector.py" "$CLAUDE_DIR/vector.py"
echo -e "  ${GREEN}✓${NC} vector.py → $CLAUDE_DIR/"

# 3. SPEAK skill
cp -r "$CTX_DIR/skills/speak/"* "$SKILLS/speak/"
echo -e "  ${GREEN}✓${NC} SPEAK skill → $SKILLS/speak/"

# 4. Domain catalog
if [[ ! -f "$CONFIG/domain-catalog.json" ]]; then
    cp "$CTX_DIR/config/domain-catalog.json" "$CONFIG/domain-catalog.json"
    echo -e "  ${GREEN}✓${NC} seeded domain-catalog.json"
else
    echo -e "  ${YELLOW}~${NC} domain-catalog.json already exists — left untouched"
fi

# 5. Register routing-check hook
python3 - <<PYEOF
import json, os
from pathlib import Path
p = Path(os.path.expanduser("~/.claude/settings.json"))
home = os.path.expanduser("~")
data = json.loads(p.read_text()) if p.exists() else {}
data.setdefault("hooks", {})
entry = {"matcher": "Agent", "hooks": [{"type":"command","command":f'bash "{home}/.claude/helpers/routing-check-hook.sh"'}]}
existing = data["hooks"].setdefault("PreToolUse", [])
if not any("routing-check-hook" in json.dumps(e) for e in existing):
    existing.append(entry)
p.write_text(json.dumps(data, indent=2, ensure_ascii=False))
print("  ✓ routing-check-hook registered in settings.json")
PYEOF

# 6. Create Qdrant collection
curl -sf -X PUT "$QDRANT_URL/collections/$COLLECTION" \
    -H 'Content-Type: application/json' \
    -d "{\"vectors\":{\"size\":$DIM,\"distance\":\"Cosine\"}}" >/dev/null \
    && echo -e "  ${GREEN}✓${NC} Qdrant collection '$COLLECTION' created (dim=$DIM)" \
    || echo -e "  ${YELLOW}~${NC} collection '$COLLECTION' may already exist"

# 7. CLI wrapper
cat > "$BIN_DIR/cortex" <<'EOF'
#!/usr/bin/env bash
cmd="${1:-help}"; shift || true
case "$cmd" in
    reflexion) bash ~/.claude/helpers/reflexion.sh "$@" ;;
    erl)       bash ~/.claude/helpers/erl.sh "$@" ;;
    expel)     bash ~/.claude/helpers/expel.sh "$@" ;;
    eval)      bash ~/.claude/helpers/longmemeval.sh "$@" ;;
    catalog)
        sub="${1:-show}"; shift || true
        case "$sub" in
            edit) ${EDITOR:-nano} ~/.claude/config/domain-catalog.json ;;
            show) cat ~/.claude/config/domain-catalog.json ;;
        esac
        ;;
    help|*)
        echo "cortex <command>"
        echo "  reflexion store|search|feedback|prune"
        echo "  erl update|show"
        echo "  eval build|run|compare"
        echo "  catalog show|edit"
        ;;
esac
EOF
chmod +x "$BIN_DIR/cortex"
echo -e "  ${GREEN}✓${NC} CLI installed: $BIN_DIR/cortex"

# 8. Smoke test
echo
echo -e "${BLUE}▶ Smoke test${NC}"
if bash "$HELPERS/reflexion.sh" store "installer smoke test error" "delete this" --category testing >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} reflexion.store ok"
else
    echo -e "  ${YELLOW}!${NC} reflexion.store failed — check Qdrant + embeddings"
fi

echo
echo -e "${GREEN}✅ Cortex installed.${NC}"
echo "   Try:   cortex reflexion store \"<error>\" \"<fix>\" --category <cat>"
echo "          cortex erl update && cortex erl show"
echo "          cortex eval build && cortex eval run"
