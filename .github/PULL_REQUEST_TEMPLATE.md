## What & why

<!-- What does this change, and why? Link any related issue (e.g. Closes #12). -->

## Checklist

- [ ] `xcodebuild test -scheme Spitr` passes locally
- [ ] New user-facing strings were added via `Scripts/gen_localization.py` (not by hand)
- [ ] Respects the fixed decisions in [CLAUDE.md](CLAUDE.md): mic only while held,
      no network calls (except WhisperKit's one-time model download), sandbox off
- [ ] Commit messages follow Conventional Commits, subject-only
