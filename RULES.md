# Repository workflow rules

- Before any work, read this file and `AGENTS.md`.
- For small tasks, delegate by default to a Luna (OpenAI) or Haiku (Anthropic) agent; use Sonnet (Anthropic) for harder tasks. Ask the user before using a more capable model.
- Do not delete files; when removal is needed, move them to a `legacy/` folder.
- Before finishing work, pull remote changes. After work is done, push all changes.
- Commit every completed job, including small changes, so it can be rewound. Use `[FLAG] description` with one of these flags: `[INIT]` first commit, `[FIX]` structural/architectural correction, `[BUGFIX]` bug fix, `[FEATURE]` beginning a feature, `[STABLE]` polished intermediate version, `[UPDATE]` other changes.
- Append a summary of every session to `docs/session-log.md` as `[date] - [time] - [what was done]`.
