# Changes

## 0.7.2-evfree-regexp-dev

- All iOS operations are now using background processing (reported to resolve intermittent problems with cordova-ios@4.0.1)
- URI encoding workaround for Cordova BUG CB-9435 (iOS *only*)

## 0.7.1-evcommon-dev

- Rename Windows C++ Database close function to closedb to resolve conflict for Windows Store certification
- Fix conversion warnings in iOS version
- Fix to Windows "Universal" version to support big integers
- Implement database close and delete operations for Windows "Universal"
- Fix readTransaction to skip BEGIN/COMMIT/ROLLBACK
