# CI Baseline

Date: 2026-07-15

Baseline tag: `fiado-app-baseline-2026-07-15`

## Purpose

The Fiado App CI validates the governed baseline automatically before changes are merged into `master`.

## Triggers

The workflow runs on:

- Pushes to `master`.
- Pull requests targeting `master`.
- Manual `workflow_dispatch` runs.

## Jobs

### Flutter Quality

Validates the Flutter application without building release artifacts:

- Installs Flutter `3.41.6` on the stable channel.
- Runs `flutter pub get`.
- Runs `dart format --output=none --set-exit-if-changed .`.
- Runs `flutter analyze`.
- Runs `flutter test`.

### Backend Build

Validates the backend solution:

- Installs .NET SDK `10.0.201`.
- Runs `dotnet restore backend/FiadoApp.Backend.sln`.
- Runs `dotnet build backend/FiadoApp.Backend.sln --no-restore --configuration Release`.
- Runs `dotnet test backend/FiadoApp.Backend.sln --no-build --configuration Release`.

The current solution contains the API project and no separate .NET test project, so the test command is retained as a baseline check without inventing tests.

## Pass Criteria

An execution is approved only when every step in every job succeeds. Formatting, analysis, Flutter tests, backend restore, backend build, and backend test failures must block the workflow.

## Non-Goals

This workflow does not:

- Deploy to Azure or any other environment.
- Publish APK, Web, Windows, or other binary artifacts.
- Create releases.
- Use production secrets.
- Modify the repository.
- Run database migrations.

## Branch Protection

`master` should later be protected in GitHub using required checks for:

- `Flutter Quality`
- `Backend Build`

Branch protection is not configured by this file and must be enabled separately in GitHub after the workflow has run at least once.
