---
type: decision
status: active
review_by: 2027-04-26
sources:
  - https://www.letta.com/blog/benchmarking-ai-agent-memory (2025-08-12)
  - https://cursor.com/blog/semsearch (undated)
  - https://arxiv.org/abs/2501.13956 (Zep/Graphiti)
  - https://blog.getzep.com/lies-damn-lies-statistics-is-mem0-really-sota-in-agent-memory/ (undated)
  - https://github.com/modelcontextprotocol/servers/tree/main/src/memory (retrieved 2026-10-26)
  - https://www.dolthub.com/blog/2026-04-02-restoring-beads-classic/ (2026-04-02)
  - https://github.com/basicmachines-co/basic-memory (retrieved 2026-10-26)
  - https://unit42.paloaltonetworks.com/indirect-prompt-injection-poisons-ai-longterm-memory.md (undated)
trust: untrusted
---
# The knowledge base is markdown in git

**Decision.** One markdown file per note under `specs/kb/`, with frontmatter (type, status,
supersedes, review_by, sources, trust), searched with grep, and reviewed in PRs. Confidence is
medium: the evidence is indirect and mostly from vendors.

## Evidence
- **Files work well for agents.** Letta's filesystem agent scored 74.0% on LoCoMo; Mem0's best
  graph variant scored 68.5%. Caveats: Letta is a vendor, its agent also had semantic search, and
  LoCoMo measures chat recall, not a curated knowledge base.
- **Grep vs RAG.** Claude Code reportedly dropped a vector index in favour of agentic search,
  citing freshness and reliability (second-hand). Cursor reports +12.5% from semantic search on
  large codebases, alongside grep rather than instead of it. Our corpus is tiny by comparison.
- **Graph memory.** Zep and Mem0 dispute each other's numbers, and the LoCoMo answer key itself
  has been criticised. Nothing independent shows graphs beating files for curated notes.
- **Merge behaviour.** The official MCP memory server uses one `memory.jsonl` with a lock, which
  breaks for a team. Beads moved JSONL to Dolt because many agents wrote to it at once; human
  notes don't have that write pattern.
- **Poisoning.** Indirect prompt injection into long-term memory is documented (Unit 42,
  MemoryGraft; OWASP ASI06). Markdown is the only option where every write shows in a diff.

## Upgrade triggers
- **Grep misses hurt** (likely at a few thousand notes): a derived, gitignored SQLite FTS5 index.
- **FTS still misses**: embeddings (sqlite-vec).
- **"What did we believe on date X" becomes a real question**: a temporal graph.
- **Many concurrent machine writers**: Dolt-style storage.

## Format
```yaml
type: research | decision | concept | lesson
status: active | superseded
supersedes: [note]
review_by: YYYY-MM-DD
sources: ["<url> (retrieved YYYY-MM-DD)"]
trust: untrusted | reviewed
```
