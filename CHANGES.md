# Changes

## 0.8.2-pre

- Android version with sqlite 3.8.10.2 and REGEXP support using PCRE (8.37)
- URI encoding workaround for Cordova BUG CB-9435 (iOS *only*)

## 0.8.1

- Multi-part transactions API (see README.md)
- Error result with proper Web SQL `code` member and `sqliteCode` as reported by the SQLite C library for Android and iOS
- Rename Windows C++ Database close function to closedb to resolve conflict for Windows Store certification
- Fix conversion warnings in iOS version
- Fix to Windows "Universal" version to support big integers
- Implement database close and delete operations for Windows "Universal"
- Fix readTransaction to skip BEGIN/COMMIT/ROLLBACK
