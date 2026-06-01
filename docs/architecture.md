# Flixie Architecture (Clean Architecture Target)

## Layer model

- **presentation/**: screens, widgets, providers, presentation controllers
- **domain/**: entities/use-cases/repository contracts
- **data/**: repository implementations and service-backed data access

## Dependency direction

Only these imports are allowed:

1. `presentation -> domain`
2. `presentation -> presentation`
3. `data -> domain`
4. `data -> services/models/utils`
5. `domain -> domain/models`

Disallowed:

- `presentation -> services` for feature data access
- `domain -> data`
- `domain -> services`

## Shared feature modules

The shared presentation modules in `lib/presentation/shared/` are the standard entry points for repeated feature flows:

- `FriendActionsController`
- `WatchlistActionsController`
- `ProfileLookupController`
- `ReviewReactionsController`
- `SettingsController`

These modules route calls through:

`controller -> usecase -> repository contract -> repository impl -> service`

## AuthProvider responsibility split

`AuthProvider` now delegates:

- prefetch orchestration to `AuthPrefetchCoordinator`
- notification polling lifecycle to `AuthNotificationPoller`

`AuthProvider` remains the session/auth state owner and UI-facing cache holder.

## Shared shell primitives

Default screen chrome for authenticated screens:

- `FlixiePageScaffold`
- `FlixieTitleAppBar`
- `FlixieSectionHeader`

### Current exception

`MovieDetailScreen` still uses direct `Scaffold` variants for its loading/error/state-specific layouts and custom immersive composition.

## Incremental migration status

- ✅ Foundation layers (`presentation/domain/data`) added
- ✅ Shared modules/controllers added for repeated social/watchlist/profile/review/settings actions
- ✅ Home, Movie Detail, Profile, Social, and Settings flows moved off direct `UserService`/`FriendService` calls
- ✅ Auth prefetch + polling responsibilities extracted from `AuthProvider`
- ⏳ Remaining screens/features should migrate to shared modules as touched by new work

## PR checklist guardrails

For architecture-sensitive PRs:

- [ ] No screen/provider introduced direct `UserService`/`FriendService` access for feature flows
- [ ] New data access introduced repository contract + data implementation
- [ ] Feature orchestration goes through use cases/controllers
- [ ] Shared shell components used unless exception is documented
