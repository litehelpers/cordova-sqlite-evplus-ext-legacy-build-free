/* 'use strict'; */

var MYTIMEOUT = 12000;

var DEFAULT_SIZE = 5000000; // max to avoid popup in safari/ios

var scenarioList = [ 'Plugin' ];
var scenarioCount = 1;

var mytests = function() {

  for (var i=0; i<scenarioCount; ++i) {

    describe(scenarioList[i] + ': multi-part tx test(s)', function() {
      var scenarioName = scenarioList[i];
      var suiteName = scenarioName + ': ';
      var isWebSql = (i === 1);
      var isOldImpl = (i === 2);

      // NOTE: MUST be defined in function scope, NOT outer scope:
      var openDatabase = function(name, ignored1, ignored2, ignored3) {
        if (isOldImpl) {
          return window.sqlitePlugin.openDatabase({name: name, iosDatabaseLocation: 'Documents', androidDatabaseImplementation: 2});
        }
        if (isWebSql) {
          return window.openDatabase(name, "1.0", "Demo", DEFAULT_SIZE);
        } else {
          // explicit database location:
          // return window.sqlitePlugin.openDatabase(name, "1.0", "Demo", DEFAULT_SIZE);
          return window.sqlitePlugin.openDatabase({name: name, location: 'default'});
        }
      }

      if (!isWebSql)
        it(suiteName + "multi-part transaction", function(done) {
          var db = openDatabase("multi-part-test.db", "1.0", "Demo", DEFAULT_SIZE);

          expect(db).toBeDefined()
          db.executeSql("DROP TABLE IF EXISTS tt");
          db.executeSql("CREATE TABLE tt (tf)");

          var tx = db.beginTransaction();

          expect(tx).toBeDefined()

          tx.executeSql("INSERT INTO tt values(?)", ['tv']);
          tx.executeSql("SELECT * from tt", [], function(tx, res) {
            expect(res.rows.item(0).tf).toEqual('tv');
            setTimeout(function() {
              tx.executeSql("SELECT * from tt", [], function(tx, res) {
                expect(res.rows.item(0).tf).toEqual('tv');

                tx.end(function() {
                  var t2 = db.beginTransaction();
                  t2.executeSql("SELECT * from tt", [], function(tx, res) {
                    expect(res.rows.item(0).tf).toEqual('tv');

                    t2.executeSql("DROP TABLE IF EXISTS tt");
                    t2.executeSql("CREATE TABLE tt (tf)");

                    t2.executeSql("INSERT INTO tt values(?)", ['t2']);
                    t2.executeSql("SELECT * from tt", [], function(tx, res) {
                      expect(res.rows.item(0).tf).toEqual('t2');

                      // test tx.abort():
                      t2.abort(function() {
                        var t3 = db.beginTransaction();
                        t3.executeSql("SELECT * from tt", [], function(tx, res) {
                          expect(res.rows.item(0).tf).toEqual('tv');
                          t3.end();
                          done();
                        });
                      });
                    });
                  });
                });
              });
            }, 0);
          }, function(err) {
            expect(false).toBe(true);
            tx.abort();
            done();
          });
        }, MYTIMEOUT);

        it(suiteName + "multi-part transaction interleaved", function(done) {
          var db = openDatabase("multi-part-interleaved-test.db", "1.0", "Demo", DEFAULT_SIZE);

          expect(db).toBeDefined()
          db.executeSql("DROP TABLE IF EXISTS tt");
          db.executeSql("CREATE TABLE tt (tf)");

          var tx1 = db.beginTransaction();

          expect(tx1).toBeDefined()

          tx1.executeSql("INSERT INTO tt values(?)", ['tv']);

          var tx2 = db.beginTransaction();

          tx1.executeSql("DROP TABLE IF EXISTS tt");
          tx1.executeSql("CREATE TABLE tt (tf)");
          tx1.executeSql("INSERT INTO tt values(?)", ['tv2']);

          tx2.executeSql("SELECT * from tt", [], function(tx, res) {
            expect(res.rows.item(0).tf).toEqual('tv2');

            // just in case:
            try {
              tx1.end();
            } catch(e) {
              // expected here
              expect(true).toBe(true);
            }

            tx2.end();
            done();
          }, function(err) {
            // not expected:
            expect(false).toBe(true);

            // just in case:
            try {
              tx.end();
            } catch(e) {
              // expected here
              expect(true).toBe(true);
            }

            tx2.end();
            done();
          });

          tx1.end();

        }, MYTIMEOUT);

        it(suiteName + "empty transaction", function(done) {
          var db = openDatabase("multi-part-empty-tx-test.db", "1.0", "Demo", DEFAULT_SIZE);

          expect(db).toBeDefined()

          var tx = db.beginTransaction();

          expect(tx).toBeDefined()

          tx.end(function() {
            done();
          }, function(err) {
            expect(false).toBe(true);
            done();
          });
        }, MYTIMEOUT);

        it(suiteName + "empty transaction end in next tick", function(done) {
          var db = openDatabase("multi-part-empty-end-next-tick.db", "1.0", "Demo", DEFAULT_SIZE);

          expect(db).toBeDefined()

          var tx = db.beginTransaction();

          expect(tx).toBeDefined()

          setTimeout(function() {
            tx.end(function() {
              done();
            }, function(err) {
              expect(false).toBe(true);
              done();
            });
          }, 0);
        }, MYTIMEOUT);

        it(suiteName + "empty transaction end after delay", function(done) {
          var mydelay = 800;

          var db = openDatabase("multi-part-empty-end-after-delay.db", "1.0", "Demo", DEFAULT_SIZE);

          expect(db).toBeDefined()

          var tx = db.beginTransaction();

          expect(tx).toBeDefined()

          setTimeout(function() {
            tx.end(function() {
              done();
            }, function(err) {
              expect(false).toBe(true);
              done();
            });
          }, mydelay);
        }, MYTIMEOUT);

        it(suiteName + "abort after delay", function(done) {
          var mydelay = 800;

          var db = openDatabase("abort-after-delay.db", "1.0", "Demo", DEFAULT_SIZE);

          expect(db).toBeDefined()

          var tx = db.beginTransaction();

          expect(tx).toBeDefined()

          setTimeout(function() {
            tx.abort(function(e) {
              done();
            });
          }, mydelay);
        }, MYTIMEOUT);

    });
  };
}

if (window.hasBrowser) mytests();
else exports.defineAutoTests = mytests;

/* vim: set expandtab : */
