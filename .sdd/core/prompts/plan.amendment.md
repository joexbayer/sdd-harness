AMENDMENT: this changes a ground truth of the system, so the bar is high.
- Start with the rule's history: `git log -p specs/constitution.md` and the item that
  added it. Ask why it exists before arguing it should change.
- Show the human everything that depends on it: `git grep -n 'C-<n>'`, plus the code the
  article governs. That list is the Impact section.
- Prefer the narrowest change that solves the evidence under "Why now".
