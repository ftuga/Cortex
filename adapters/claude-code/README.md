# claude code adapter

default target. `install.sh` at repo root does everything:

1. copies `hooks/*.sh` and `hooks/vector.py` → `~/.claude/helpers/`
2. copies `skills/speak/` → `~/.claude/skills/speak/`
3. copies `config/domain-catalog.json` → `~/.claude/config/` (if absent)
4. registers `routing-check.sh` on `PreToolUse(Task)` in `settings.json`
5. creates qdrant `reflexions` collection (dim=384 default)
6. installs `~/.local/bin/cortex` CLI dispatcher

## prerequisites

a running qdrant instance:

```bash
docker run -d --name qdrant -p 6333:6333 \
    -v qdrant_storage:/qdrant/storage qdrant/qdrant
```

## manual install

```bash
mkdir -p ~/.claude/helpers ~/.claude/skills/speak ~/.claude/config
cp hooks/*.sh hooks/vector.py ~/.claude/helpers/
cp skills/speak/SKILL.md ~/.claude/skills/speak/
cp config/domain-catalog.json ~/.claude/config/
chmod +x ~/.claude/helpers/*.sh

# register routing hook in ~/.claude/settings.json under "hooks":
#   PreToolUse → matcher "Task" → ~/.claude/helpers/routing-check.sh

# initialize qdrant collection
python3 ~/.claude/helpers/vector.py init
```
