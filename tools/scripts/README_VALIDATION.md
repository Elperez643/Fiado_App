# Windows Validation Scripts

Codex must not run Flutter or Dart validation commands directly on Windows.
Use these timeout wrappers instead:

```powershell
powershell -ExecutionPolicy Bypass -File tools\scripts\validate_flutter.ps1
```

The validation script runs, in order:

```text
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

Each command has a timeout and writes a log under:

```text
tools\logs
```

Individual APK build:

```powershell
powershell -ExecutionPolicy Bypass -File tools\scripts\build_debug_apk.ps1
```

Generic wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File tools\scripts\run_with_timeout.ps1 -FilePath C:\flutter\bin\cache\dart-sdk\bin\dart.exe -Arguments @("--version") -TimeoutSeconds 30 -LogFile tools\logs\dart_version.log
```

Runner diagnostics:

```powershell
powershell -ExecutionPolicy Bypass -File tools\scripts\doctor_runner.ps1
```

The scripts use `FLUTTER_ROOT` when present. Otherwise they use `C:\flutter`.
`dart` commands are executed through `bin\cache\dart-sdk\bin\dart.exe` to avoid
the `dart.bat` shim hanging in automated Windows shells.

Exit codes:

```text
0    success
124  timeout
other command exit code
```
