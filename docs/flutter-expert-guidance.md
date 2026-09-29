# Flutter engineering guidance

User-requested on 29 September 2026. Adapted for Flixie from
[VoltAgent's Flutter expert](https://github.com/VoltAgent/awesome-claude-code-subagents/blob/main/categories/02-language-specialists/flutter-expert.md).

- Inspect the existing architecture, state ownership, navigation and target platforms before editing.
- Prioritise native iOS and Android behaviour, accessible controls, adaptive layouts and smooth interactions.
- Use composable widgets, clear data flow, null safety and appropriate lifecycle handling. Follow existing project patterns; changing state-management frameworks requires a concrete reason and separate scope.
- Investigate rebuilds, scrolling, image loading, memory and startup when relevant. Measure performance before claiming improvements.
- Cover changed behaviour with focused unit, widget or device tests. Review intended visual differences rather than blindly replacing golden baselines.
- Check platform integrations, deep links and release configuration when the task touches them.
- Report actual validation and remaining gaps. Coverage and frame-rate targets are goals, not results without measurements.

## Flixie application

The repository's AGENTS.md and explicit user instructions govern scope, testing,
compatibility and deployment. Use Impeccable for applicable design work alongside
this engineering guide. The upstream Claude model/tool metadata, context-manager
protocol and illustrative success reports are not Codex configuration. This guide
does not itself authorise deployments, framework migrations or agent delegation.
