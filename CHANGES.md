# Changes

## 0.8.3

- Fix sqlitePlugin.openDatabase and sqlitePlugin.deleteDatabase to check location/iosDatabaseLocation values
- Fix sqlitePlugin.deleteDatabase to check that db name is really a string (prevents possible crash on iOS)
- Support location: 'default' setting in openDatabase & deleteDatabase
- More explicit iosDatabaseLocation option
- iOS database location is now mandatory

## 0.8.2

- Support pre-populated database for Android, iOS
- BROKEN: pre-populated database for Windows "Universal"
- All iOS operations are now using background processing (reported to resolve intermittent problems with cordova-ios@4.0.1)

## 0.8.2-pre

- REGEXP support for Android (using PCRE with sqlite 3.8.10.2) and iOS (using built-in regex library)
- URI encoding workaround for Cordova BUG CB-9435 (iOS *only*)

## 0.8.1

- Multi-part transactions API (see README.md)
- Error result with proper Web SQL `code` member and `sqliteCode` as reported by the SQLite C library for Android and iOS
- Rename Windows C++ Database close function to closedb to resolve conflict for Windows Store certification
- Fix conversion warnings in iOS version
- Fix to Windows "Universal" version to support big integers
- Implement database close and delete operations for Windows "Universal"
- Fix readTransaction to skip BEGIN/COMMIT/ROLLBACK
