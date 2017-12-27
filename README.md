# Cordova/PhoneGap sqlite storage - premium enterprise version with legacy support for internal memory improvements and other enhancements
 
Native interface to sqlite in a Cordova/PhoneGap plugin for Android, iOS, macOS, and Windows 8.1(+)/Windows Phone 8.1(+) with API similar to HTML5/[Web SQL API](http://www.w3.org/TR/webdatabase/).

This version is available under GPL v3 (http://www.gnu.org/licenses/gpl.txt) or premium commercial license.

TBD: no Circle CI or Travis CI working in this version branch.

NOTE: Commercial licenses for Cordova-sqlite-enterprise-free purchased before July 2016 are valid for this version. Commercial licenses for Cordova-sqlite-evcore versions are *not* valid for this version.

This version is in legacy maintenance status. Only security and extremely critical bug fixes will be considered.

## BREAKING CHANGE: Database location parameter is now mandatory

The `location` or `iosDatabaseLocation` *must* be specified in the `openDatabase` and `deleteDatabase` calls, as documented below.

### IMPORTANT: iCloud backup of SQLite database is NOT allowed

As documented in the "**A User’s iCloud Storage Is Limited**" section of [iCloudFundamentals in Mac Developer Library iCloud Design Guide](https://developer.apple.com/library/mac/documentation/General/Conceptual/iCloudDesignGuide/Chapters/iCloudFundametals.html) (near the beginning):

<blockquote>
<ul>
<li><b>DO</b> store the following in iCloud:
  <ul>
   <li>[<i>other items omitted</i>]</li>
   <li>Change log files for a SQLite database (a SQLite database’s store file must never be stored in iCloud)</li>
  </ul>
</li>
<li><b>DO NOT</b> store the following in iCloud:
  <ul>
   <li>[<i>items omitted</i>]</li>
  </ul>
</li>
</ul>
- <cite><a href="https://developer.apple.com/library/mac/documentation/General/Conceptual/iCloudDesignGuide/Chapters/iCloudFundametals.html">iCloudFundamentals in Mac Developer Library iCloud Design Guide</a>
</blockquote>

### How to disable iCloud backup

Use the `location` or `iosDatabaseLocation` option in `sqlitePlugin.openDatabase()` to store the database in a subdirectory that is *NOT* backed up to iCloud, as described in the section below.

**NOTE:** Changing `BackupWebStorage` in `config.xml` has no effect on a database created by this plugin. `BackupWebStorage` applies only to local storage and/or Web SQL storage created in the WebView (*not* using this plugin). For reference: [phonegap/build#338 (comment)](https://github.com/phonegap/build/issues/338#issuecomment-113328140)

## Status

- The iOS database location is now mandatory, as documented below.
- Patches patches will *NOT* be accepted on this project due to potential licensing issues.
- omitted from this version branch: WP(7/8)
- Amazon Fire-OS is dropped due to lack of support by Cordova. Android version should be used to deploy to Fire-OS 5.0(+) devices ref: [cordova/cordova-discuss#32 (comment)](https://github.com/cordova/cordova-discuss/issues/32#issuecomment-167021676)
- Windows "Universal" for Windows 8.0/8.1(+) and Windows Phone 8.1(+) version is in an alpha state:
  - Issue with UNICODE `\u0000` character (same as `\0`)
  - No background processing (for future consideration)
  - You *may* encounter issues with Cordova CLI due to [CB-8866](https://issues.apache.org/jira/browse/CB-8866). *Old workaround:* you can install using [litehelpers / cordova-windows-nufix](https://github.com/litehelpers/cordova-windows-nufix) and `plugman` as described below.
  - In addition, problems with the Windows "Universal" version have been reported in case of a Cordova project using a Visual Studio template/extension instead of Cordova/PhoneGap CLI or `plugman`
  - Not tested with a Windows 10 (or Windows Phone 10) target; Windows 10 build is not expected to work with Windows Phone
- Status for the other target platforms:
  - Android: now using [Android-sqlite-connector](https://github.com/liteglue/Android-sqlite-connector) (with sqlite `3.8.10.2`), with support for FTS3/FTS4 and R-Tree, and REGEXP support using PCRE 8.37 as built from [liteglue / Android-sqlite-native-driver-regexp-pcre](https://github.com/liteglue/Android-sqlite-native-driver-regexp-pcre)
  - iOS/macOS: sqlite `3.8.10.2` embedded
- Android is supported back to SDK 10 (a.k.a. Gingerbread, Android 2.3.3); support for older versions is available upon request.
- API to open the database may be changed somewhat to be more streamlined. Transaction and single-statement query API will NOT be changed.

## Announcements

- More explicit `openDatabase` and `deleteDatabase` `iosDatabaseLocation` option
- Pre-populated database support for Android, iOS, macOS, ~~and Windows "Universal" (_broken_)~~, usage described below
- REGEXP is now supported for Android and iOS/macOS platforms.
- This version has the following improvement(s):
  - iOS/macOS _platform_ version can now handle all UNICODE characters, using URI encoding as a workaround for [Cordova bug CB-9435](https://issues.apache.org/jira/browse/CB-9435).
  - Multi-part transactions API (described below)
  - Error result with proper Web SQL `code` member and `sqliteCode` as reported by the SQLite C library (Android/iOS)
  - flat JSON interface between Javascript and native parts
  - *optional*: transaction sql chunking, which can be enabled by changing the `MAX_SQL_CHUNK` value in SQLitePlugin.js
- A version with support for web workers is available at: [litehelpers / Cordova-sqlite-evplus-legacy-workers-free](https://github.com/litehelpers/Cordova-sqlite-evplus-legacy-workers-free)
- All iOS/macOS operations are now using background processing (reported to resolve intermittent problems with cordova-ios@4.0.1)
- Published [brodybits / Cordova-quick-start-checklist](https://github.com/brodybits/Cordova-quick-start-checklist) and [brodybits / Cordova-troubleshooting-guide](https://github.com/brodybits/Cordova-troubleshooting-guide)
- PhoneGap Build is now supported through the npm package: http://phonegap.com/blog/2015/05/26/npm-plugins-available/
- [MetaMemoryT / websql-promise](https://github.com/MetaMemoryT/websql-promise) now provides a Promises-based interface to both Web SQL and this plugin
-- iOS/macOS _platform_ version is now fixed to override the correct pluginInitialize method and should work with recent versions of iOS
- New `openDatabase` and `deleteDatabase` `location` option to select database location (iOS/macOS *only*) and disable iCloud backup
- Fixes to work with PouchDB by [@nolanlawson](https://github.com/nolanlawson)

## Highlights

- Drop-in replacement for HTML5/[Web SQL API](http://www.w3.org/TR/webdatabase/): the only change should be to replace the static `window.openDatabase()` factory call with `window.sqlitePlugin.openDatabase()`, with parameters as documented below. (*NOTE:* Some known deviations are described below).
- Failure-safe nested transactions with batch processing optimizations (according to HTML5/[Web SQL API](http://www.w3.org/TR/webdatabase/))
- FTS3, FTS4, and R-Tree support is tested working OK in this version
- As described in [this posting](http://brodyspark.blogspot.com/2012/12/cordovaphonegap-sqlite-plugins-offer.html):
  - Keeps sqlite database in a user data location that is known; can be reconfigured (iOS/macOS platform version); may be synchronized to iCloud (iOS _platform_ version).
  - No 5MB maximum, more information at: http://www.sqlite.org/limits.html
- Pre-populated openDatabase option (usage described below)

## Some apps using this plugin

- REDCap Mobile App (part of [Project REDCap Software](http://projectredcap.org/software.php) for data collection)

TBD *your app here*

## Some known deviations from the Web SQL database standard

- The `window.sqlitePlugin.openDatabase` static factory call takes a different set of parameters than the standard Web SQL `window.openDatabase` static factory call. In case you have to use existing Web SQL code with no modifications please see the **Web SQL replacement tip** below.
- This plugin does *not* support the database creation callback or standard database versions. Please read the **Database schema versions** section below for tips on how to support database schema versioning.
- This plugin does *not* support the synchronous Web SQL interfaces.
- Error reporting is not 100% compliant, with some issues described below.
- In case of a transaction with an sql statement error for which there is no error handler, the error handler does not return `false`, or the error handler throws an exception, the plugin will fire more sql statement callbacks before the transaction is aborted with ROLLBACK.
- This plugin supports some non-standard features as described below.

## Known issues

- iOS/macOS platform version does not support certain rapidly repeated open-and-close or open-and-delete test scenarios due to how the implementation handles background processing
- As described below, auto-vacuum is NOT enabled by default.
- A stability issue was reported on the iOS version when in use together with [SockJS](http://sockjs.org/) client such as [pusher-js](https://github.com/pusher/pusher-js) at the same time (see [litehelpers/Cordova-sqlite-storage#196](https://github.com/litehelpers/Cordova-sqlite-storage/issues/196)). The workaround is to call sqlite functions and [SockJS](http://sockjs.org/) client functions in separate ticks (using setTimeout with 0 timeout).
- If a sql statement fails for which there is no error handler or the error handler does not return `false` to signal transaction recovery, the plugin fires the remaining sql callbacks before aborting the transaction.
- In case of an error, the error `code` member is bogus on Windows (fixed for Android in this version).
- Possible crash on Android when using Unicode emoji characters due to [Android bug 81341](https://code.google.com/p/android/issues/detail?id=81341), which _should_ be fixed in Android 6.x
- In-memory database `db=window.sqlitePlugin.openDatabase({name: ":memory:"})` is currently not supported.
- Pre-populated database is known to be BROKEN on Windows in this version.
- Close/delete database bugs described below.
- When a database is opened and deleted without closing, the iOS/macOS platform version is known to leak resources.
- It is NOT possible to open multiple databases with the same name but in different locations (iOS/macOS platform version).
- Problems reported with PhoneGap Build in the past:
  - PhoneGap Build Hydration.
  - Apparently FIXED: ~~For some reason, PhoneGap Build may fail to build the iOS version unless the name of the app starts with an uppercase and contains no spaces (see [#243](https://github.com/litehelpers/Cordova-sqlite-storage/issues/243); [Wizcorp/phonegap-facebook-plugin#830](https://github.com/Wizcorp/phonegap-facebook-plugin/issues/830); [phonegap/build#431](https://github.com/phonegap/build/issues/431)).~~

## Other limitations

- The db version, display name, and size parameter values are not supported and will be ignored.
- Absolute and relative subdirectory path(s) are not tested or supported.
- This plugin will not work before the callback for the 'deviceready' event has been fired, as described in **Usage**. (This is consistent with the other Cordova plugins.)
- This version will not work within a web worker (not properly supported by the Cordova framework). Version with support for web workers, along with the memory and iOS/macOS Unicode character fixes from this project at: [litehelpers / Cordova-sqlite-evplus-legacy-workers-free](https://github.com/litehelpers/Cordova-sqlite-evplus-legacy-workers-free)
- REGEXP is missing for Windows (for future consideration) and has different regex implementations for Android and iOS/macOS.
- In-memory database `db=window.sqlitePlugin.openDatabase({name: ":memory:"})` is currently not supported.
- The Android version cannot work with more than 100 open db files (due to the threading model used).
- Blob type is currently not supported and known to be broken on multiple platforms.
- UNICODE `\u0000` (same as `\0`) character not working in Android or Windows/Windows Phone (8.1/XX)
- Case-insensitive matching and other string manipulations on Unicode characters, which is provided by optional ICU integration in the sqlite source and working with recent versions of Android, is not supported for any target platforms.
- iOS/macOS platform version uses a thread pool but with only one thread working at a time due to "synchronized" database access
- Large query result can be slow, also due to JSON implementation
- ATTACH another database file is not supported. Version with support for ATTACH, along with the memory and iOS/macOS Unicode character fixes from this project (*Android error fix currently missing*) at: [litehelpers / Cordova-sqlite-evplus-legacy-ext-free](https://github.com/litehelpers/Cordova-sqlite-evplus-legacy-ext-free)
- User-defined savepoints are not supported and not expected to be compatible with the transaction locking mechanism used by this plugin. In addition, the use of BEGIN/COMMIT/ROLLBACK statements is not supported.
- Problems have been reported when using this plugin with Crosswalk (for Android). It may help to install Crosswalk as a plugin instead of using Crosswalk to create the project.
- Does not work with [axemclion / react-native-cordova-plugin](https://github.com/axemclion/react-native-cordova-plugin) since the `window.sqlitePlugin` object is *not* proprly exported (ES5 feature). It is recommended to use [andpor / react-native-sqlite-storage](https://github.com/andpor/react-native-sqlite-storage) for SQLite database access with React Native Android/iOS instead.

## Further testing needed

- Multi-page apps
- Use within [InAppBrowser](http://docs.phonegap.com/en/edge/cordova_inappbrowser_inappbrowser.md.html)
- Use within an iframe (see [litehelpers/Cordova-sqlite-storage#368 (comment)](https://github.com/litehelpers/Cordova-sqlite-storage/issues/368#issuecomment-154046367))
- Actual behavior when using SAVEPOINT(s)
- ~~R-Tree is not tested for all older releases of Android in case [Android-sqlite-connector](https://github.com/liteglue/Android-sqlite-connector) is disabled (using the `androidDatabaseImplementation` option in `window.sqlitePlugin.openDatabase`)~~
- UNICODE characters not fully tested
- Use with TRIGGER(s), JOIN and ORDER BY RANDOM
- TODO add some *more* REGEXP tests
- UPDATE/DELETE with LIMIT or ORDER BY (newer Android/iOS versions)
- Integration with JXCore for Cordova (must be built without sqlite(3) built-in)
- Delete an open database inside a statement or transaction callback.

## Some tips and tricks

- If you run into problems and your code follows the asynchronous HTML5/[Web SQL](http://www.w3.org/TR/webdatabase/) transaction API, you can try opening a test database using `window.openDatabase` and see if you get the same problems.
- In case your database schema may change, it is recommended to keep a table with one row and one column to keep track of your own schema version number. It is possible to add it later. The recommended schema update procedure is described below.

## Common pitfall(s)

- It is NOT allowed to execute sql statements on a transaction following the HTML5/[Web SQL API](http://www.w3.org/TR/webdatabase/), as described below.
- Not in this version branch: ~~It is possible to make a Windows Phone 8.1 project using either the `windows` platform or the `wp8` platform. The `windows` platform is highly recommended over `wp8` whenever possible. Also, some plugins only support `windows` and some plugins support only `wp8`.~~
- The plugin class name starts with "SQL" in capital letters, but in Javascript the `sqlitePlugin` object name starts with "sql" in small letters.
- Attempting to open a database before receiving the 'deviceready' event callback.
- Inserting STRING into ID field
- Auto-vacuum is NOT enabled by default. It is recommended to periodically VACUUM the database.

## Weird pitfall(s)

- intent whitelist: blocked intent such as external URL intent *may* cause this and perhaps certain Cordova plugin(s) to misbehave (see [litehelpers/Cordova-sqlite-storage#396](https://github.com/litehelpers/Cordova-sqlite-storage/issues/396))

## Angular/ngCordova/Ionic-related pitfalls

- Angular/ngCordova/Ionic controller/factory/service callbacks may be triggered before the 'deviceready' event is fired
- As discussed in [litehelpers/Cordova-sqlite-storage#355](https://github.com/litehelpers/Cordova-sqlite-storage/issues/355), it may be necessary to install ionic-plugin-keyboard

## Major TODOs

- Integrate with IndexedDBShim and some other libraries such as Sequelize, Squel.js, WebSqlSync, Persistence.js, Knex, etc.

## Alternatives

### Other versions

- [litehelpers / Cordova-sqlite-evplus-legacy-ext-free](https://github.com/litehelpers/Cordova-sqlite-evplus-legacy-ext-free) - version with support for ATTACH (Windows support missing), includes the memory and iOS Unicode character fixes from this project
- [litehelpers / Cordova-sqlite-evplus-legacy-workers-free](https://github.com/litehelpers/Cordova-sqlite-evplus-legacy-workers-free) - version with support for web workers (Android and iOS *only*), includes the memory and iOS Unicode character fixes from this project
- [litehelpers / Cordova-sqlite-storage](https://github.com/litehelpers/Cordova-sqlite-storage) - Cordova sqlite storage plugin with permissive licensing terms
- [litehelpers / Cordova-sqlcipher-adapter](https://github.com/litehelpers/Cordova-sqlcipher-adapter) - supports [SQLCipher](https://www.zetetic.net/sqlcipher/) for Android, iOS, and Windows (8.1) (with permissive licensing terms)
- Adaptation for React Native Android and iOS: [andpor / react-native-sqlite-storage](https://github.com/andpor/react-native-sqlite-storage)
- Original version for iOS (with a slightly different transaction API): [davibe / Phonegap-SQLitePlugin](https://github.com/davibe/Phonegap-SQLitePlugin)

### Other SQLite adapter projects

- [object-layer / AnySQL](https://github.com/object-layer/anysql) - Unified SQL API over multiple database engines
- [an-rahulpandey / cordova-plugin-dbcopy](https://github.com/an-rahulpandey/cordova-plugin-dbcopy) - (Alternative way to) add support for pre-populated database
- Simpler sqlite plugin with a simpler API: [samikrc / CordovaSQLite](https://github.com/samikrc/CordovaSQLite)
- [EionRobb / phonegap-win8-sqlite](https://github.com/EionRobb/phonegap-win8-sqlite) - WebSQL add-on for Win8/Metro apps (perhaps with a different API), using an old version of the C++ library from [SQLite3-WinRT Component](https://github.com/doo/SQLite3-WinRT) (as referenced by [01org / cordova-win8](https://github.com/01org/cordova-win8))
- [SQLite3-WinRT Component](https://github.com/doo/SQLite3-WinRT) - C++ component that provides a nice SQLite API with promises for WinJS
- [01org / cordova-win8](https://github.com/01org/cordova-win8) - old, unofficial version of Cordova API support for Windows 8 Metro that includes an old version of the C++ [SQLite3-WinRT Component](https://github.com/doo/SQLite3-WinRT)
- [MSOpenTech / cordova-plugin-websql](https://github.com/MSOpenTech/cordova-plugin-websql) - Windows 8(+) and Windows Phone 8(+) WebSQL plugin versions in C#
- [Thinkwise / cordova-plugin-websql](https://github.com/Thinkwise/cordova-plugin-websql) - fork of [MSOpenTech / cordova-plugin-websql](https://github.com/MSOpenTech/cordova-plugin-websql) that supports asynchronous execution
- [MetaMemoryT / websql-client](https://github.com/MetaMemoryT/websql-client) - provides the same API and connects to [websql-server](https://github.com/MetaMemoryT/websql-server) through WebSockets.

### Alternative solutions

- [ABB-Austin / cordova-plugin-indexeddb-async](https://github.com/ABB-Austin/cordova-plugin-indexeddb-async) - Asynchronous IndexedDB plugin for Cordova that uses [axemclion / IndexedDBShim](https://github.com/axemclion/IndexedDBShim) (Browser/iOS/Android/Windows) and [Thinkwise / cordova-plugin-websql](https://github.com/Thinkwise/cordova-plugin-websql) - (Windows)
- Another sqlite binding for React-Native (iOS version): [almost/react-native-sqlite](https://github.com/almost/react-native-sqlite)
- Use [NativeScript](https://www.nativescript.org) with its web view and [NathanaelA / nativescript-sqlite](https://github.com/Natha
naelA/nativescript-sqlite) (Android and/or iOS)
- Standard HTML5 [local storage](https://en.wikipedia.org/wiki/Web_storage#localStorage)
- [Realm.io](https://realm.io/)

# Usage

## General

The idea is to emulate the HTML5/[Web SQL API](http://www.w3.org/TR/webdatabase/) as closely as possible. The only major change is to use `window.sqlitePlugin.openDatabase()` (or `sqlitePlugin.openDatabase()`) *with parameters as documented below* instead of `window.openDatabase()`. If you see any other major change please report it, it is probably a bug.

**NOTE:** If a sqlite statement in a transaction fails with an error, the error handler *must* return `false` in order to recover the transaction. This is correct according to the HTML5/[Web SQL API](http://www.w3.org/TR/webdatabase/) standard. This is different from the WebKit implementation of Web SQL in Android and iOS which recovers the transaction if a sql error hander returns a non-`true` value.

## Opening a database

To open a database access handle object (in the **new** default location):

```js
var db = window.sqlitePlugin.openDatabase({name: 'my.db', location: 'default'}, successcb, errorcb);
```

**WARNING:** The new "default" location value is *NOT* the same as the old default location and would break an upgrade for an app that was using the old default value (0) on iOS.

To specify a different location (affects iOS/macOS *only*):

```js
var db = window.sqlitePlugin.openDatabase({name: 'my.db', iosDatabaseLocation: 'Library'}, successcb, errorcb);
```

where the `iosDatabaseLocation` option may be set to one of the following choices:
- `default`: `Library/LocalDatabase` subdirectory - *NOT* visible to iTunes and *NOT* backed up by iCloud
- `Library`: `Library` subdirectory - backed up by iCloud, *NOT* visible to iTunes
- `Documents`: `Documents` subdirectory - visible to iTunes and backed up by iCloud

**WARNING:** Again, the new "default" iosDatabaseLocation value is *NOT* the same as the old default location and would break an upgrade for an app using the old default value (0) on iOS.

*ALTERNATIVE (deprecated):*
- `var db = window.sqlitePlugin.openDatabase({name: "my.db", location: 1}, successcb, errorcb);`

with the `location` option set to one the following choices (affects iOS/macOS *only*):
- `0` ~~(default)~~: `Documents` - visible to iTunes and backed up by iCloud
- `1`: `Library` - backed up by iCloud, *NOT* visible to iTunes
- `2`: `Library/LocalDatabase` - *NOT* visible to iTunes and *NOT* backed up by iCloud (same as using "default")

No longer supported (see tip below to overwrite `window.openDatabase`): ~~`var db = window.sqlitePlugin.openDatabase("myDatabase.db", "1.0", "Demo", -1);`~~

**IMPORTANT:** Please wait for the 'deviceready' event, as in the following example:

```js
// Wait for Cordova to load
document.addEventListener('deviceready', onDeviceReady, false);

// Cordova is ready
function onDeviceReady() {
  var db = window.sqlitePlugin.openDatabase({name: 'my.db', location: 'default'});
  // ...
}
```

The successcb and errorcb callback parameters are optional but can be extremely helpful in case anything goes wrong. For example:

```js
window.sqlitePlugin.openDatabase({name: 'my.db', location: 'default'}, function(db) {
  db.transaction(function(tx) {
    // ...
  }, function(err) {
    console.log('Open database ERROR: ' + JSON.stringify(err));
  });
});
```

If any sql statements or transactions are attempted on a database object before the openDatabase result is known, they will be queued and will be aborted in case the database cannot be opened.

**OTHER NOTES:**
- The database file name should include the extension, if desired.
- It is possible to open multiple database access handle objects for the same database.
- The database handle access object can be closed as described below.

**TIP:**

To overwrite `window.openDatabase`:

```Javascript
window.openDatabase = function(dbname, ignored1, ignored2, ignored3) {
  return window.sqlitePlugin.openDatabase({name: dbname, location: 'default'});
};
```

### Pre-populated database(s)

Put the database file in the `www` directory and open the database like (**both** database location and `createFromLocation` items are required):

```js
var db = window.sqlitePlugin.openDatabase({name: "my.db", location: 'default', createFromLocation: 1});
```

**IMPORTANT NOTES:**

- Put the pre-populated database file in the `www` subdirectory. (This should work well the Cordova CLI.)
- The pre-populated database file name must match **exactly** the file name given in `openDatabase`. This plugin does *not* use an automatic extension.
- The pre-populated database file is ignored if the database file with the same name already exists in your database file location.

**TIP:** If you don't see the data from the pre-populated database file, completely remove your app and try it again!

**Alternative:** You can also use [an-rahulpandey / cordova-plugin-dbcopy](https://github.com/an-rahulpandey/cordova-plugin-dbcopy) to install a pre-populated database

**Samples and tutorials:**

- Ionic starter template with pre-populated SQLite database at: [jdnichollsc / Ionic-Starter-Template](https://github.com/jdnichollsc/Ionic-Starter-Template)
- http://redwanhilali.com/ionic-sqlite/
- Tutorial using [an-rahulpandey / cordova-plugin-dbcopy (alternative solution)](https://github.com/an-rahulpandey/cordova-plugin-dbcopy) (Android/iOS): https://blog.nraboy.com/2015/01/deploy-ionic-framework-app-pre-filled-sqlite-db/
- https://github.com/brodybits/Cordova-pre-populated-db-example-android (based on Cordova 2.7)

## SQL transactions

The following types of SQL transactions are supported by this version:
- Single-statement transactions
- Standard asynchronous transactions
- Multi-part transactions

### Single-statement transactions

Sample (with both success and error callbacks):

```Javascript
db.executeSql("SELECT LENGTH('tenletters') AS stringlength", [], function (res) {
  console.log('got stringlength: ' + res.rows.item(0).stringlength);
}, function(error) {
  console.log('SELECT error: ' + error.message);
});
```

### Standard asynchronous transactions

Standard asynchronous transactions follow the HTML5/[Web SQL API](http://www.w3.org/TR/webdatabase/) which is very well documented and uses BEGIN and COMMIT or ROLLBACK to keep the transactions failure-safe. Here is a very simple example from the test suite (with success and error callbacks):

```Javascript
db.transaction(function(tx) {
  tx.executeSql("SELECT UPPER('Some US-ASCII text') AS uppertext", [], function(tx, res) {
    console.log("res.rows.item(0).uppertext: " + res.rows.item(0).uppertext);
  }, function(tx, error) {
    console.log('SELECT error: ' + error.message);
  });
}, function(error) {
  console.log('transaction error: ' + error.message);
}, function() {
  console.log('transaction ok');
});
```

In case of a read-only transaction, it is possible to use `readTransaction` which will not use BEGIN, COMMIT, or ROLLBACK:

```Javascript
db.readTransaction(function(tx) {
  tx.executeSql("SELECT UPPER('Some US-ASCII text') AS uppertext", [], function(tx, res) {
    console.log("res.rows.item(0).uppertext: " + res.rows.item(0).uppertext);
  }, function(tx, error) {
    console.log('SELECT error: ' + error.message);
  });
}, function(error) {
  console.log('transaction error: ' + error.message);
}, function() {
  console.log('transaction ok');
});
```

**NOTICE:** The `tx.executeSql` success and error callbacks should take two parameters (first parameter for the transaction object). This is different from the single-statement success and error callbacks described above.

**WARNING:** It is NOT allowed to execute sql statements on a transaction after it has finished. Here is an example from my [Populating Cordova SQLite storage with the JQuery API post](http://www.brodybits.com/cordova/sqlite/api/jquery/2015/10/26/populating-cordova-sqlite-storage-with-the-jquery-api.html):

```Javascript
  // BROKEN SAMPLE:
  db.executeSql("DROP TABLE IF EXISTS tt");
  db.executeSql("CREATE TABLE tt (data)");

  db.transaction(function(tx) {
    $.ajax({
      url: 'https://api.github.com/users/litehelpers/repos',
      dataType: 'json',
      success: function(res) {
        console.log('Got AJAX response: ' + JSON.stringify(res));
        $.each(res, function(i, item) {
          console.log('REPO NAME: ' + item.name);
          tx.executeSql("INSERT INTO tt values (?)", JSON.stringify(item.name));
        });
      }
    });
  }, function(e) {
    console.log('Transaction error: ' + e.message);
  }, function() {
    // Check results:
    db.executeSql('SELECT COUNT(*) FROM tt', [], function(res) {
      console.log('Check SELECT result: ' + JSON.stringify(res.rows.item(0)));
    });
  });
```

You can find more details and a step-by-step description how to do this right in the [Populating Cordova SQLite storage with the JQuery API post](http://www.brodybits.com/cordova/sqlite/api/jquery/2015/10/26/populating-cordova-sqlite-storage-with-the-jquery-api.html):

### Multi-part transactions

Sample (with success and error callbacks):

```Javascript
var tx = db.beginTransaction();
tx.executeSql("DROP TABLE IF EXISTS mytable");
tx.executeSql("CREATE TABLE mytable (myfield)");

tx.executeSql("INSERT INTO mytable values(?)", ['test value']);
tx.executeSql("SELECT * from mytable", [], function(tx, res) {
  console.log("Got value: " + res.rows.item(0).myfield);
}, function(tx, e) {
  console.log("Ignore unexpected error callback with message: " + e.message);
  return false;
});

tx.end(function() {
  console.log('Optional success callback fired');
}, function(e) {
  console.log("Optional error callback fired with message: " + e.message);
});
```

Sample with abort:

```Javascript
var tx = db.beginTransaction();
tx.executeSql("INSERT INTO mytable values(?)", ['wrong data']);
tx.abort(function() {
  console.log('Optional callback');
});
```

IMPORTANT NOTES:
- In case a `tx.executeSql` call results in an error and it does not have an error callback or the error callback does NOT return `false`, the transaction will be aborted *immediately* with a ROLLBACK ~~upon the `tx.end` call~~.
- **BUG:** If a `tx.executeSql` call results in an error for which there is no error callback, the error callback does NOT return `false`, or the error callback throws an exception, the transaction is silently aborted and no `tx.end` callbacks will be fired.
- When a multi-part transaction is started by the `db.beginTransaction` call, all other transactions are blocked until the multi-part transaction is either completed successfully or aborted (with a ROLLBACK).

## Background processing

The threading model depends on which version is used:
- For Android, one background thread per db;
- for iOS/macOS, background processing using a very limited thread pool (only one thread working at a time);
- for Windows "Universal" (8.1), no background processing (for future consideration).

## Sample with PRAGMA feature

First we create a table and add a single entry, then query the count to check if the item was inserted as expected. Note that a new transaction is created in the middle of the first callback.

```js
// Wait for Cordova to load
document.addEventListener('deviceready', onDeviceReady, false);

// Cordova is ready
function onDeviceReady() {
  var db = window.sqlitePlugin.openDatabase({name: "my.db"});

  db.transaction(function(tx) {
    tx.executeSql('DROP TABLE IF EXISTS test_table');
    tx.executeSql('CREATE TABLE IF NOT EXISTS test_table (id integer primary key, data text, data_num integer)');

    // demonstrate PRAGMA:
    db.executeSql("pragma table_info (test_table);", [], function(res) {
      console.log("PRAGMA res: " + JSON.stringify(res));
    });

    tx.executeSql("INSERT INTO test_table (data, data_num) VALUES (?,?)", ["test", 100], function(tx, res) {
      console.log("insertId: " + res.insertId + " -- probably 1");
      console.log("rowsAffected: " + res.rowsAffected + " -- should be 1");

      db.transaction(function(tx) {
        tx.executeSql("select count(id) as cnt from test_table;", [], function(tx, res) {
          console.log("res.rows.length: " + res.rows.length + " -- should be 1");
          console.log("res.rows.item(0).cnt: " + res.rows.item(0).cnt + " -- should be 1");
        });
      });

    }, function(e) {
      console.log("ERROR: " + e.message);
    });
  });
}
```

**NOTE:** PRAGMA statements must be executed in `executeSql()` on the database object (i.e. `db.executeSql()`) and NOT within a transaction.

## Sample with transaction-level nesting

In this case, the same transaction in the first executeSql() callback is being reused to run executeSql() again.

```js
// Wait for Cordova to load
document.addEventListener('deviceready', onDeviceReady, false);

// Cordova is ready
function onDeviceReady() {
  var db = window.sqlitePlugin.openDatabase("Database", "1.0", "Demo", -1);

  db.transaction(function(tx) {
    tx.executeSql('DROP TABLE IF EXISTS test_table');
    tx.executeSql('CREATE TABLE IF NOT EXISTS test_table (id integer primary key, data text, data_num integer)');

    tx.executeSql("INSERT INTO test_table (data, data_num) VALUES (?,?)", ["test", 100], function(tx, res) {
      console.log("insertId: " + res.insertId + " -- probably 1");
      console.log("rowsAffected: " + res.rowsAffected + " -- should be 1");

      tx.executeSql("select count(id) as cnt from test_table;", [], function(tx, res) {
        console.log("res.rows.length: " + res.rows.length + " -- should be 1");
        console.log("res.rows.item(0).cnt: " + res.rows.item(0).cnt + " -- should be 1");
      });

    }, function(e) {
      console.log("ERROR: " + e.message);
    });
  });
}
```

This case will also works with Safari (WebKit), assuming you replace `window.sqlitePlugin.openDatabase` with `window.openDatabase`.

## Close a database object

```js
db.close(successcb, errorcb);
```

It is OK to close the database within a transaction callback but *NOT* within a statement callback. The following example is OK:

```Javascript
db.transaction(function(tx) {
  tx.executeSql("SELECT LENGTH('tenletters') AS stringlength", [], function(tx, res) {
    console.log('got stringlength: ' + res.rows.item(0).stringlength);
  });
}, function(error) {
  // OK to close here:
  console.log('transaction error: ' + error.message);
  db.close();
}, function() {
  // OK to close here:
  console.log('transaction ok');
  db.close(function() {
    console.log('database is closed ok');
  });
});
```

The following example is NOT OK:

```Javascript
// BROKEN:
db.transaction(function(tx) {
  tx.executeSql("SELECT LENGTH('tenletters') AS stringlength", [], function(tx, res) {
    console.log('got stringlength: ' + res.rows.item(0).stringlength);
    // BROKEN - this will trigger the error callback:
    db.close(function() {
      console.log('database is closed ok');
    }, function(error) {
      console.log('ERROR closing database');
    });
  });
});
```

**BUG 1:** It is currently NOT possible to close a database in a `db.executeSql` callback. For example:

```Javascript
// BROKEN DUE TO BUG:
db.executeSql("SELECT LENGTH('tenletters') AS stringlength", [], function (res) {
  var stringlength = res.rows.item(0).stringlength;
  console.log('got stringlength: ' + res.rows.item(0).stringlength);

  // BROKEN - this will trigger the error callback DUE TO BUG:
  db.close(function() {
    console.log('database is closed ok');
  }, function(error) {
    console.log('ERROR closing database');
  });
});
```

**BUG 2:** If multiple database access objects are opened for the same database and one database access object is closed, the database is no longer available for the other database access objects. Possible workarounds:
- It is still possible to open one or more new database access objects on a database that has been closed.
- It *should* be OK not to explicitly close a database handle since database transactions are [ACID](https://en.wikipedia.org/wiki/ACID) compliant and the app's memory resources are cleaned up by the system upon termination.

## Delete a database

```js
window.sqlitePlugin.deleteDatabase({name: "my.db", location: 1}, successcb, errorcb);
```

`location` as described above for `openDatabase` (iOS/macOS *only*)

# Schema versions

The transactional nature of the API makes it relatively straightforward to manage a database schema that may be upgraded over time (adding new columns or new tables, for example). Here is the recommended procedure to follow upon app startup:
- Check your database schema version number (you can use `db.executeSql` since it should be a very simple query)
- If your database needs to be upgraded, do the following *within a single transaction* to be failure-safe:
  - Create your database schema version table (single row single column) if it does not exist (you can check the `sqlite_master` table as described at: http://stackoverflow.com/questions/1601151/how-do-i-check-in-sqlite-whether-a-table-exists)
  - Add any missing columns and tables, and apply any other changes necessary

**IMPORTANT:** Since we cannot be certain when the users will actually update their apps, old schema versions will have to be supported for a very long time.

## Use with Ionic/ngCordova/Angular

It is recommended to follow the tutorial at: https://blog.nraboy.com/2014/11/use-sqlite-instead-local-storage-ionic-framework/

Documentation at: http://ngcordova.com/docs/plugins/sqlite/

# Installing

## Windows "Universal" target platform

**IMPORTANT:** There are issues supporing certain Windows target platforms due to [CB-8866](https://issues.apache.org/jira/browse/CB-8866):
- When using Visual Studio, the default target ("Mixed Platforms") will not work
- Problems have been with the Windows "Universal" version case of a Cordova project using a Visual Studio template/extension instead of Cordova/PhoneGap CLI or `plugman`

*Old workaround:* As an alternative, which will support the ("Mixed Platforms") target, you can use `plugman` instead with [litehelpers / cordova-windows-nufix](https://github.com/litehelpers/cordova-windows-nufix), as described here.

### Old workaround - Using plugman to support "Mixed Platforms"

- make sure you have the latest version of `plugman` installed: `npm install -g plugman`
- Download the [cordova-windows-nufix 3.9.0-nufixpre-01 zipball](https://github.com/litehelpers/cordova-windows-nufix/archive/3.9.0-nufixpre-01.zip) (or you can clone [litehelpers / cordova-windows-nufix](https://github.com/litehelpers/cordova-windows-nufix) instead)
- Create your Windows "Universal" (8.1) project using [litehelpers / cordova-windows-nufix](https://github.com/litehelpers/cordova-windows-nufix):
  - `path.to.cordova-windows-nufix/bin/create.bat your_app_path your.app.id YourAppName`
- `cd your_app_path` and install plugin using `plugman`:
  - `plugman install --platform windows --project . --plugin https://github.com/litehelpers/Cordova-sqlite-evplus-legacy-free`
- Put your sql program in your project `www` (don't forget to reference it from `www\index.html` and wait for `deviceready` event)

Then your project in `CordovaApp.sln` should work with "Mixed Platforms" on both Windows 8.1 and Windows Phone 8.1.

## Easy install with Cordova CLI tool

    npm install -g cordova # if you don't have cordova
    cordova create MyProjectFolder com.my.project MyProject && cd MyProjectFolder # if you are just starting
    cordova plugin add https://github.com/litehelpers/Cordova-sqlite-evplus-legacy-free
 
You can find more details at [this writeup](http://iphonedevlog.wordpress.com/2014/04/07/installing-chris-brodys-sqlite-database-with-cordova-cli-android/).

**WARNING:** for Windows target platform please read the section below.

**IMPORTANT:** sometimes you have to update the version for a platform before you can build, like: `cordova prepare ios`

**NOTE:** If you cannot build for a platform after `cordova prepare`, you may have to remove the platform and add it again, such as:

    cordova platform rm ios
    cordova platform add ios

## Easy install with plugman tool

```shell
plugman install --platform MYPLATFORM --project path.to.my.project.folder --plugin https://github.com/litehelpers/Cordova-sqlite-evplus-legacy-free
```

where MYPLATFORM is `android`, `ios`, or `windows`.

A posting how to get started developing on Windows host without the Cordova CLI tool (for Android target only) is available [here](http://brodybits.blogspot.com/2015/03/trying-cordova-for-android-on-windows-without-cordova-cli.html).

## Source tree

- `SQLitePlugin.coffee.md`: platform-independent (Literate coffee-script, can be read by recent coffee-script compiler)
- `www`: `SQLitePlugin.js` platform-independent Javascript as generated from `SQLitePlugin.coffee.md` (and checked in!)
- `src`: platform-specific source code:
   - `external` - placeholder for external dependencies - *not needed in this version branch*
   - `common` - common dependencies: `sqlite3.[hc]` (needed to build iOS/macOS and Windows _platform_ versions)
   - `android` - Java plugin code for Android
   - `ios` - Objective-C plugin code for iOS/macOS;
   - `windows` - Javascript proxy code and SQLite3-WinRT project for Windows "Universal" (8.1);
- `spec`: test suite using Jasmine (2.2.0), ported from QUnit `test-www` test suite, working on all platforms
- `tests`: very simple Jasmine test suite that is run on Circle CI (Android version) and Travis CI (iOS version)
- `Lawnchair-adapter`: Lawnchair adaptor, based on the version from the Lawnchair repository, with the basic Lawnchair test suite in `test-www` subdirectory

## Manual installation - Android version

These installation instructions are based on the Android example project from Cordova/PhoneGap 2.7.0, using the `lib/android/example` subdirectory from the PhoneGap 2.7 zipball.

 - Install `SQLitePlugin.js` from `www` into `assets/www`
 - Install `SQLitePlugin.java` from `src/android/io/liteglue` into `src/io/liteglue` subdirectory
 - Install the `libs` subtree from `common` with `sqlite-connector.jar` and `sqlite-native-driver.jar` into your Android project
 - Add the plugin element `<plugin name="SQLitePlugin" value="io.liteglue.SQLitePlugin"/>` to `res/xml/config.xml`

Sample change to `res/xml/config.xml` for Cordova/PhoneGap 2.x:

```diff
--- config.xml.orig	2015-04-14 14:03:05.000000000 +0200
+++ res/xml/config.xml	2015-04-14 14:08:08.000000000 +0200
@@ -36,6 +36,7 @@
     <preference name="useBrowserHistory" value="true" />
     <preference name="exit-on-suspend" value="false" />
 <plugins>
+    <plugin name="SQLitePlugin" value="io.liteglue.SQLitePlugin"/>
     <plugin name="App" value="org.apache.cordova.App"/>
     <plugin name="Geolocation" value="org.apache.cordova.GeoBroker"/>
     <plugin name="Device" value="org.apache.cordova.Device"/>
```

Before building for the first time, you have to update the project with the desired version of the Android SDK with a command like:

    android update project --path $(pwd) --target android-19

(assuming Android SDK 19, use the correct desired Android SDK number here)

**NOTE:** using this plugin on Cordova pre-3.0 requires the following changes to `SQLitePlugin.java`:

```diff
diff -u Cordova-sqlite-storage/src/android/io/liteglue/SQLitePlugin.java src/io/liteglue/SQLitePlugin.java
--- Cordova-sqlite-storage/src/android/io/liteglue/SQLitePlugin.java	2015-04-14 14:05:01.000000000 +0200
+++ src/io/liteglue/SQLitePlugin.java	2015-04-14 14:10:44.000000000 +0200
@@ -22,8 +22,8 @@
 import java.util.regex.Matcher;
 import java.util.regex.Pattern;
 
-import org.apache.cordova.CallbackContext;
-import org.apache.cordova.CordovaPlugin;
+import org.apache.cordova.api.CallbackContext;
+import org.apache.cordova.api.CordovaPlugin;
 
 import org.json.JSONArray;
 import org.json.JSONException;
```

## Manual installation - iOS version

### SQLite library

In the Project "Build Phases" tab, select the _first_ "Link Binary with Libraries" dropdown menu and add the library `libsqlite3.dylib` or `libsqlite3.0.dylib`.

**NOTE:** In the "Build Phases" there can be multiple "Link Binary with Libraries" dropdown menus. Please select the first one otherwise it will not work.

### SQLite Plugin

- Copy `SQLitePlugin.[hm]` from `src/ios` into your project Plugins folder and add them in XCode (I always just have "Create references" as the option selected).
- Copy `SQLitePlugin.js` from `www` into your project `www` folder
- Enable the SQLitePlugin in `config.xml`

Sample change to `config.xml` for Cordova/PhoneGap 2.x:

```diff
--- config.xml.old	2013-05-17 13:18:39.000000000 +0200
+++ config.xml	2013-05-17 13:18:49.000000000 +0200
@@ -39,6 +39,7 @@
     <content src="index.html" />
 
     <plugins>
+        <plugin name="SQLitePlugin" value="SQLitePlugin" />
         <plugin name="Device" value="CDVDevice" />
         <plugin name="Logger" value="CDVLogger" />
         <plugin name="Compass" value="CDVLocation" />
```

## Manual installation - Windows "Universal" (8.1) version

Described above.

## Quick installation test

Assuming your app has a recent template as used by the Cordova create script, add the following code to the `onDeviceReady` function, after `app.receivedEvent('deviceready');`:

```Javascript
  window.sqlitePlugin.openDatabase({ name: 'hello-world.db' }, function (db) {
    db.executeSql("select length('tenletters') as stringlength", [], function (res) {
      var stringlength = res.rows.item(0).stringlength;
      console.log('got stringlength: ' + stringlength);
      document.getElementById('deviceready').querySelector('.received').innerHTML = 'stringlength: ' + stringlength;
   });
  });
```

### Old installation test

Make a change like this to index.html (or use the sample code) verify proper installation:

```diff
--- index.html.old	2012-08-04 14:40:07.000000000 +0200
+++ assets/www/index.html	2012-08-04 14:36:05.000000000 +0200
@@ -24,7 +24,35 @@
     <title>PhoneGap</title>
       <link rel="stylesheet" href="master.css" type="text/css" media="screen" title="no title">
       <script type="text/javascript" charset="utf-8" src="cordova-2.0.0.js"></script>
-      <script type="text/javascript" charset="utf-8" src="main.js"></script>
+      <script type="text/javascript" charset="utf-8" src="SQLitePlugin.js"></script>
+
+
+      <script type="text/javascript" charset="utf-8">
+      document.addEventListener("deviceready", onDeviceReady, false);
+      function onDeviceReady() {
+        var db = window.sqlitePlugin.openDatabase("Database", "1.0", "Demo", -1);
+
+        db.transaction(function(tx) {
+          tx.executeSql('DROP TABLE IF EXISTS test_table');
+          tx.executeSql('CREATE TABLE IF NOT EXISTS test_table (id integer primary key, data text, data_num integer)');
+
+          tx.executeSql("INSERT INTO test_table (data, data_num) VALUES (?,?)", ["test", 100], function(tx, res) {
+          console.log("insertId: " + res.insertId + " -- probably 1"); // check #18/#38 is fixed
+          alert("insertId: " + res.insertId + " -- should be valid");
+
+            db.transaction(function(tx) {
+              tx.executeSql("SELECT data_num from test_table;", [], function(tx, res) {
+                console.log("res.rows.length: " + res.rows.length + " -- should be 1");
+                alert("res.rows.item(0).data_num: " + res.rows.item(0).data_num + " -- should be 100");
+              });
+            });
+
+          }, function(e) {
+            console.log("ERROR: " + e.message);
+          });
+        });
+      }
+      </script>
 
   </head>
   <body onload="init();" id="stage" class="theme">
```

# Support

## Reporting issues

If you have an issue with the plugin please check the following first:
- You are using the latest version of the Plugin Javascript & platform-specific Java or Objective-C source from this repository.
- You have installed the Javascript & platform-specific Java or Objective-C correctly.
- You have included the correct version of the cordova Javascript and SQLitePlugin.js and got the path right.
- You have registered the plugin properly in `config.xml`.

If you still cannot get something to work, please create a fresh, clean Cordova project, add this plugin according to the instructions above, and try a simple test program.

If you continue to see the issue in a new, clean Cordova project:
- Make the simplest test program you can to demonstrate the issue, including the following characteristics:
  - it completely self-contained, i.e. it is using no extra libraries beyond cordova & SQLitePlugin.js;
  - if the issue is with *adding* data to a table, that the test program includes the statements you used to open the database and create the table;
  - if the issue is with *retrieving* data from a table, that the test program includes the statements you used to open the database, create the table, and enter the data you are trying to retrieve.

Then you can [raise the new issue](https://github.com/litehelpers/Cordova-sqlite-evplus-legacy-free/issues/new).

## Commercial support

You may contact info@litehelpers.net

# Unit tests

Unit testing is done in `spec`.

## running tests from shell

To run the tests from \*nix shell, simply do either:

    ./bin/test.sh ios

or for Android:

    ./bin/test.sh android

To run from a windows powershell (here is a sample for android target):

    .\bin\test.ps1 android

# Adapters

## Lawnchair Adapter

**BROKEN:** The Lawnchair adapter does not support the `openDatabase` options such as `location` or `iosDatabaseLocation` options and is therefore *not* expected to work with this plugin.

### Common adapter

Please look at the `Lawnchair-adapter` tree that contains a common adapter, which should also work with the Android version, along with a test-www directory.

### Included files

Include the following Javascript files in your HTML:

- `cordova.js` (don't forget!)
- `lawnchair.js` (you provide)
- `SQLitePlugin.js` (in case of Cordova pre-3.0)
- `Lawnchair-sqlitePlugin.js` (must come after `SQLitePlugin.js` in case of Cordova pre-3.0)

### Sample

The `name` option determines the sqlite database filename, *with no extension automatically added*. Optionally, you can change the db filename using the `db` option.

In this example, you would be using/creating a database with filename `kvstore`:

```Javascript
kvstore = new Lawnchair({name: "kvstore"}, function() {
  // do stuff
);
```

Using the `db` option you can specify the filename with the desired extension and be able to create multiple stores in the same database file. (There will be one table per store.)

```Javascript
recipes = new Lawnchair({db: "cookbook", name: "recipes", ...}, myCallback());
ingredients = new Lawnchair({db: "cookbook", name: "ingredients", ...}, myCallback());
```

**KNOWN ISSUE:** the new db options are *not* supported by the Lawnchair adapter. The workaround is to first open the database file using `sqlitePlugin.openDatabase()`.

## PouchDB

The adapter is now part of [PouchDB](http://pouchdb.com/) thanks to [@nolanlawson](https://github.com/nolanlawson), see [PouchDB FAQ](http://pouchdb.com/faq.html).

**NOTE:** The PouchDB adapter has not been tested with the Android version which is using the new [Android-sqlite-connector](https://github.com/liteglue/Android-sqlite-connector).

# Contributing

## Community

- Testimonials of apps that are using this plugin would be especially helpful.
- Reporting issues at [litehelpers / Cordova-sqlite-evplus-legacy-free / issues](https://github.com/litehelpers/Cordova-sqlite-evplus-legacy-free/issues) can help improve the quality of this plugin.

**NOTE:** As stated above, patches will *NOT* be accepted on this project due to potential licensing issues. Issues with reproduction scenarios will help maintain and improve the quality of this plugin for future users. (It is also helpful if you have a pointer to the code that is causing the issue.)

# External sources

- https://github.com/liteglue/Android-sqlite-connector
- https://github.com/liteglue/Android-sqlite-native-driver

## Contact

info@litehelpers.net
