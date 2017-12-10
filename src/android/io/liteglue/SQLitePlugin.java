/*
 * Copyright (c) 2012-2016: Christopher J. Brody (aka Chris Brody)
 * Copyright (c) 2005-2010, Nitobi Software Inc.
 * Copyright (c) 2010, IBM Corporation
 *
 * License for this version: GPL v3 (http://www.gnu.org/licenses/gpl.txt) or commercial license.
 * Contact for commercial license: info@litehelpers.net
 */

package io.liteglue;

import android.annotation.SuppressLint;

import android.util.Log;

import java.io.File;

import java.lang.IllegalArgumentException;
import java.lang.Number;

import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.LinkedBlockingQueue;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;

public class SQLitePlugin extends CordovaPlugin {

    /**
     * Multiple database runner map (static).
     *
     * NOTE: no public static accessor to db (runner) map since it is not
     * expected to work properly with db threading.
     *
     * FUTURE TBD put DBRunner into a public class that can provide external accessor.
     *
     * ADDITIONAL NOTE: Storing as Map<String, DBRunner> to avoid portabiity issue
     * between Java 6/7/8 as discussed in:
     * https://gist.github.com/AlainODea/1375759b8720a3f9f094
     *
     * THANKS to @NeoLSN (Jason Yang/楊朝傑) for giving the pointer in:
     * https://github.com/litehelpers/Cordova-sqlite-storage/issues/727
     */
    static Map<String, DBRunner> dbrmap = new ConcurrentHashMap<String, DBRunner>();

    /**
     * SQLiteConnector for native sqlite library access
     */
    static SQLiteConnector connector = new SQLiteConnector();

    /**
     * NOTE: Using default constructor, no explicit constructor.
     */

    /**
     * Executes the request and returns PluginResult.
     *
     * @param actionAsString The action to execute.
     * @param args   JSONArry of arguments for the plugin.
     * @param cbc    Callback context from Cordova API
     * @return       Whether the action was valid.
     */
    @Override
    public boolean execute(String actionAsString, JSONArray args, CallbackContext cbc) {

        Action action;
        try {
            action = Action.valueOf(actionAsString);
        } catch (IllegalArgumentException e) {
            // shouldn't ever happen
            Log.e(SQLitePlugin.class.getSimpleName(), "unexpected error", e);
            return false;
        }

        try {
            return executeAndPossiblyThrow(action, args, cbc);
        } catch (JSONException e) {
            // TODO: signal JSON problem to JS
            Log.e(SQLitePlugin.class.getSimpleName(), "unexpected error", e);
            return false;
        }
    }

    private boolean executeAndPossiblyThrow(Action action, JSONArray args, CallbackContext cbc)
            throws JSONException {

        boolean status = true;
        JSONObject o;
        String dbname;

        switch (action) {
            case open:
                o = args.getJSONObject(0);
                dbname = o.getString("name");
                // open database and start reading its queue
                this.startDatabase(dbname, o, cbc);
                break;

            case close:
                o = args.getJSONObject(0);
                dbname = o.getString("path");
                // put request in the q to close the db
                this.closeDatabase(dbname, cbc);
                break;

            case delete:
                o = args.getJSONObject(0);
                dbname = o.getString("path");

                deleteDatabase(dbname, cbc);

                break;

            case executeSqlBatch:
            case backgroundExecuteSqlBatch:
                JSONObject allargs = args.getJSONObject(0);

                JSONObject dbargs = allargs.getJSONObject("dbargs");
                dbname = dbargs.getString("dbname");

                int mylen = allargs.getInt("flen");

                JSONArray flatlist = allargs.getJSONArray("flatlist");
                int ai = 0;

                String[] queries = new String[mylen];

                // XXX TODO: currently goes through flatlist in multiple [2] passes
                for (int i = 0; i < mylen; i++) {
                    queries[i] = flatlist.getString(ai++);
                    int alen = flatlist.getInt(ai++);
                    ai += alen;
                }

                // put db query in the queue to be executed in the db thread:
                DBQuery q = new DBQuery(queries, flatlist, cbc);
                DBRunner r = dbrmap.get(dbname);
                if (r != null) {
                    try {
                        r.q.put(q); 
                    } catch(Exception e) {
                        Log.e(SQLitePlugin.class.getSimpleName(), "couldn't add to queue", e);
                        cbc.error("couldn't add to queue");
                    }
                } else {
                    cbc.error("database not open");
                }
                break;
        }

        return status;
    }

    /**
     * Clean up and close all open databases.
     */
    @Override
    public void onDestroy() {
        while (!dbrmap.isEmpty()) {
            String dbname = dbrmap.keySet().iterator().next();

            this.closeDatabaseNow(dbname);

            DBRunner r = dbrmap.get(dbname);
            try {
                // stop the db runner thread:
                r.q.put(new DBQuery());
            } catch(Exception e) {
                Log.e(SQLitePlugin.class.getSimpleName(), "couldn't stop db thread", e);
            }
            dbrmap.remove(dbname);
        }
    }

    // --------------------------------------------------------------------------
    // LOCAL METHODS
    // --------------------------------------------------------------------------

    private void startDatabase(String dbname, JSONObject options, CallbackContext cbc) {
        // TODO: is it an issue that we can orphan an existing thread?  What should we do here?
        // If we re-use the existing DBRunner it might be in the process of closing...
        DBRunner r = dbrmap.get(dbname);

        // Brody TODO: It may be better to terminate the existing db thread here & start a new one, instead.
        if (r != null) {
            // don't orphan the existing thread; just re-open the existing database.
            // In the worst case it might be in the process of closing, but even that's less serious
            // than orphaning the old DBRunner.
            cbc.success("a1"); // Indicate Android version with flat JSON interface
        } else {
            r = new DBRunner(dbname, options, cbc);
            dbrmap.put(dbname, r);
            this.cordova.getThreadPool().execute(r);
        }
    }
    /**
     * Open a database.
     *
     * @param dbName   The name of the database file
     */
    private SQLiteConnection openDatabase(String dbname, boolean createFromResource,
                                          CallbackContext cbc) throws Exception {
        try {
            // ASSUMPTION: no db (connection/handle) is already stored in the map
            // [should be true according to the code in DBRunner.run()]

            File dbfile = this.cordova.getActivity().getDatabasePath(dbname);

            if (!dbfile.exists() && createFromResource) this.createFromResource(dbname, dbfile);

            if (!dbfile.exists()) {
                dbfile.getParentFile().mkdirs();
            }

            Log.v("info", "Open sqlite db: " + dbfile.getAbsolutePath());

            SQLiteConnection mydbc = connector.newSQLiteConnection(dbfile.getAbsolutePath(),
                SQLiteOpenFlags.READWRITE | SQLiteOpenFlags.CREATE);

            // Indicate Android version with flat JSON interface
            cbc.success("a1");

            return mydbc;
        } catch (Exception e) {
            cbc.error("can't open database " + e);
            throw e;
        }
    }

    /**
     * Create from resource (assets) for pre-populated database
     *
     * If a prepopulated DB file exists in the assets folder it is copied to the dbPath.
     * Only runs the first time the app runs.
     */
    private void createFromResource(String myDBName, File dbfile)
    {
        // IMPLEMENTATION based on various sources:
        InputStream in = null;
        OutputStream out = null;

        try {
            in = this.cordova.getActivity().getAssets().open("www/" + myDBName);
            String dbPath = dbfile.getAbsolutePath();
            dbPath = dbPath.substring(0, dbPath.lastIndexOf("/") + 1);

            File dbPathFile = new File(dbPath);
            if (!dbPathFile.exists())
                dbPathFile.mkdirs();

            File newDbFile = new File(dbPath + myDBName);
            out = new FileOutputStream(newDbFile);

            // XXX TODO: this is very primitive, other alternatives at:
            // http://www.journaldev.com/861/4-ways-to-copy-file-in-java
            byte[] buf = new byte[1024];
            int len;
            while ((len = in.read(buf)) > 0)
                out.write(buf, 0, len);
    
            Log.v("info", "Copied prepopulated DB content to: " + newDbFile.getAbsolutePath());
        } catch (IOException e) {
            Log.v("createFromResource", "No prepopulated DB found, Error=" + e.getMessage());
        } finally {
            if (in != null) {
                try {
                    in.close();
                } catch (IOException ignored) {
                    Log.v("info", "Error closing input DB file, ignored");
                }
            }
    
            if (out != null) {
                try {
                    out.close();
                } catch (IOException ignored) {
                    Log.v("info", "Error closing output DB file, ignored");
                }
            }
        }
    }

    /**
     * Close a database (in another thread).
     *
     * @param dbName   The name of the database file
     */
    private void closeDatabase(String dbname, CallbackContext cbc) {
        DBRunner r = dbrmap.get(dbname);
        if (r != null) {
            try {
                r.q.put(new DBQuery(false, cbc));
            } catch(Exception e) {
                if (cbc != null) {
                    cbc.error("couldn't close database" + e);
                }
                Log.e(SQLitePlugin.class.getSimpleName(), "couldn't close database", e);
            }
        } else {
            if (cbc != null) {
                cbc.success();
            }
        }
    }

    /**
     * Close a database (in the current thread).
     *
     * @param dbname   The name of the database file
     */
    private void closeDatabaseNow(String dbname) {
        DBRunner r = dbrmap.get(dbname);

        if (r != null) {
            SQLiteConnection mydbc = r.mydbc;

            try {
                if (mydbc != null)
                    mydbc.dispose();
            } catch(Exception e) {
                Log.e(SQLitePlugin.class.getSimpleName(), "couldn't close database", e);
            }
        }
    }

    private void deleteDatabase(String dbname, CallbackContext cbc) {
        DBRunner r = dbrmap.get(dbname);
        if (r != null) {
            try {
                r.q.put(new DBQuery(true, cbc));
            } catch(Exception e) {
                if (cbc != null) {
                    cbc.error("couldn't close database" + e);
                }
                Log.e(SQLitePlugin.class.getSimpleName(), "couldn't close database", e);
            }
        } else {
            boolean deleteResult = this.deleteDatabaseNow(dbname);
            if (deleteResult) {
                cbc.success();
            } else {
                cbc.error("couldn't delete database");
            }
        }
    }

    /**
     * Delete a database.
     *
     * @param dbName   The name of the database file
     *
     * @return true if successful or false if an exception was encountered
     */
    private boolean deleteDatabaseNow(String dbname) {
        File dbfile = this.cordova.getActivity().getDatabasePath(dbname);

        try {
            return cordova.getActivity().deleteDatabase(dbfile.getAbsolutePath());
        } catch (Exception e) {
            Log.e(SQLitePlugin.class.getSimpleName(), "couldn't delete database", e);
            return false;
        }
    }

    /**
     * Executes a batch request and sends the results via cbc.
     *
     * @param mydbc      sqlite connection reference
     * @param queryarr   Array of query strings
     * @param flatlist   Flat array of JSON query statements and parameters
     * @param cbc        Callback context from Cordova API
     */
    void executeSqlBatch(SQLiteConnection mydbc, String[] queryarr, JSONArray flatlist, CallbackContext cbc) {
        if (mydbc == null) {
            // not allowed - can only happen if someone has closed (and possibly deleted) a database and then re-used the database
            cbc.error("database has been closed");
            return;
        }

        int len = queryarr.length;
        JSONArray batchResultsList = new JSONArray();

        int ai=0;

        for (int i = 0; i < len; i++) {
            int rowsAffectedCompat = 0;
            boolean needRowsAffectedCompat = false;

            try {
                String query = queryarr[i];

                ai++;
                int alen = flatlist.getInt(ai++);

                // Need to do this in case this.executeSqlStatement() throws:
                int query_ai = ai;
                ai += alen;

                this.executeSqlStatement(mydbc, query, flatlist, query_ai, alen, batchResultsList);
            } catch (Exception ex) {
                ex.printStackTrace();
                Log.e("executeSqlBatch", "SQLitePlugin.executeSql[Batch](): Error=" + ex.getMessage());
                // TODO what to do?
            }
        }

        cbc.success(batchResultsList);
    }

    private void executeSqlStatement(SQLiteConnection mydbc, String query, JSONArray paramsAsJson,
                                     int firstParamIndex, int paramCount, JSONArray batchResultsList) throws Exception {
        boolean hasRows = false;

        SQLiteStatement myStatement = null;

        long newTotal = 0;
        long rowsAffected = 0;
        long insertId = -1;

        String errorMessage = null;
        int sqlite_error_code = -1;

        try {
            myStatement = mydbc.prepareStatement(query);

            for (int i = 0; i < paramCount; ++i) {
                int jsonParamIndex = firstParamIndex + i;
                if (paramsAsJson.isNull(jsonParamIndex)) {
                    myStatement.bindNull(i + 1);
                } else {
                    Object p = paramsAsJson.get(jsonParamIndex);
                    if (p instanceof Float || p instanceof Double) 
                        myStatement.bindDouble(i + 1, paramsAsJson.getDouble(jsonParamIndex));
                    else if (p instanceof Number) 
                        myStatement.bindLong(i + 1, paramsAsJson.getLong(jsonParamIndex));
                    else
                        myStatement.bindTextNativeString(i + 1, paramsAsJson.getString(jsonParamIndex));
                }
            }

            long lastTotal = mydbc.getTotalChanges();
            hasRows = myStatement.step();

            newTotal = mydbc.getTotalChanges();
            rowsAffected = newTotal - lastTotal;

            if (rowsAffected > 0)
                insertId = mydbc.getLastInsertRowid();

        } catch (java.sql.SQLException ex) {
            ex.printStackTrace();
            sqlite_error_code= ex.getErrorCode();
            errorMessage = ex.getMessage();
            Log.e("executeSqlBatch", "SQLitePlugin.executeSql[Batch](): sqlite error code: " + sqlite_error_code + " message: " + errorMessage);
        } catch (Exception ex) {
            ex.printStackTrace();
            errorMessage = ex.getMessage();
            Log.e("executeSqlBatch", "SQLitePlugin.executeSql[Batch](): Error=" + errorMessage);
        }

        // If query result has rows
        if (hasRows) {
            String key = "";
            int colCount = myStatement.getColumnCount();

            // XXX ASSUMPTION: in this case insertId & rowsAffected would not apply here
            batchResultsList.put("okrows");

            // Build up JSON result object for each row
            do {
                try {
                    batchResultsList.put(colCount);

                    for (int i = 0; i < colCount; ++i) {
                        key = myStatement.getColumnName(i);
                        batchResultsList.put(key);

                        switch (myStatement.getColumnType(i)) {
                        case SQLColumnType.NULL:
                            batchResultsList.put(JSONObject.NULL);
                            break;

                        case SQLColumnType.REAL:
                            batchResultsList.put(myStatement.getColumnDouble(i));
                            break;

                        case SQLColumnType.INTEGER:
                            batchResultsList.put(myStatement.getColumnLong(i));
                            break;

                        // For TEXT & BLOB:
                        default:
                            batchResultsList.put(myStatement.getColumnTextNativeString(i));
                        }

                    }

                } catch (JSONException e) {
                    e.printStackTrace();
                    // TODO what to do?
                }
            } while (myStatement.step());

            batchResultsList.put("endrows");
        } else if (errorMessage != null) {
            batchResultsList.put("error");
            switch (sqlite_error_code) {
            case SQLCode.ERROR:
                batchResultsList.put(5); // SQLException.SYNTAX_ERR
                break;
            case 13: // SQLITE_FULL
                batchResultsList.put(4); // SQLException.QUOTA_ERR
                break;
            case 19: // SQLITE_CONSTRAINT
                batchResultsList.put(6); // SQLException.CONSTRAINT_ERR
                break;
            default:
                batchResultsList.put(0); // SQLException.UNKNOWN_ERR
            }
            batchResultsList.put(sqlite_error_code);
            batchResultsList.put(errorMessage);
        } else if (rowsAffected > 0) {
            batchResultsList.put("ch2");
            batchResultsList.put(rowsAffected);
            batchResultsList.put(insertId);
        } else {
            batchResultsList.put("ok");
        }

        if (myStatement != null) myStatement.dispose();
    }

    private class DBRunner implements Runnable {
        final String dbname;
        private boolean createFromResource;

        /* ** Will be ignored by this version:
        private boolean oldImpl;
        private boolean bugWorkaround;
        // ** */

        final BlockingQueue<DBQuery> q;
        final CallbackContext openCbc;

        SQLiteConnection mydbc;

        DBRunner(final String dbname, JSONObject options, CallbackContext cbc) {
            this.dbname = dbname;
            this.createFromResource = options.has("createFromResource");

            /* ** Will be ignored by this version:
            this.oldImpl = options.has("androidOldDatabaseImplementation");
            Log.v(SQLitePlugin.class.getSimpleName(), "Android db implementation: " + (oldImpl ? "OLD" : "sqlite4java (NDK)"));
            this.bugWorkaround = this.oldImpl && options.has("androidBugWorkaround");
            if (this.bugWorkaround)
                Log.v(SQLitePlugin.class.getSimpleName(), "Android db closing/locking workaround applied");
            // ** */

            this.q = new LinkedBlockingQueue<DBQuery>();
            this.openCbc = cbc;
        }

        public void run() {
            try {
                this.mydbc =
                    openDatabase(dbname, this.createFromResource, this.openCbc);
            } catch (Exception e) {
                Log.e(SQLitePlugin.class.getSimpleName(), "unexpected error, stopping db thread", e);
                dbrmap.remove(dbname);
                return;
            }

            DBQuery dbq = null;

            try {
                dbq = q.take();

                while (!dbq.stop) {
                    executeSqlBatch(mydbc, dbq.queries, dbq.flatlist, dbq.cbc);

                    dbq = q.take();
                }
            } catch (Exception e) {
                Log.e(SQLitePlugin.class.getSimpleName(), "unexpected error", e);
            }

            if (dbq != null && dbq.close) {
                try {
                    closeDatabaseNow(dbname);

                    dbrmap.remove(dbname); // (should) remove ourself

                    if (!dbq.delete) {
                        dbq.cbc.success();
                    } else {
                        try {
                            boolean deleteResult = deleteDatabaseNow(dbname);
                            if (deleteResult) {
                                dbq.cbc.success();
                            } else {
                                dbq.cbc.error("couldn't delete database");
                            }
                        } catch (Exception e) {
                            Log.e(SQLitePlugin.class.getSimpleName(), "couldn't delete database", e);
                            dbq.cbc.error("couldn't delete database: " + e);
                        }
                    }                    
                } catch (Exception e) {
                    Log.e(SQLitePlugin.class.getSimpleName(), "couldn't close database", e);
                    if (dbq.cbc != null) {
                        dbq.cbc.error("couldn't close database: " + e);
                    }
                }
            }
        }
    }

    private final class DBQuery {
        // XXX TODO replace with DBRunner action enum:
        final boolean stop;
        final boolean close;
        final boolean delete;
        final String[] queries;
        final JSONArray flatlist;
        final CallbackContext cbc;

        DBQuery(String[] myqueries, JSONArray flatlist, CallbackContext c) {
            this.stop = false;
            this.close = false;
            this.delete = false;
            this.queries = myqueries;
            this.flatlist = flatlist;
            this.cbc = c;
        }

        DBQuery(boolean delete, CallbackContext cbc) {
            this.stop = true;
            this.close = true;
            this.delete = delete;
            this.queries = null;
            this.flatlist = null;
            this.cbc = cbc;
        }

        // signal the DBRunner thread to stop:
        DBQuery() {
            this.stop = true;
            this.close = false;
            this.delete = false;
            this.queries = null;
            this.flatlist = null;
            this.cbc = null;
        }
    }

    private static enum Action {
        open,
        close,
        delete,
        executeSqlBatch,
        backgroundExecuteSqlBatch,
    }
}

/* vim: set expandtab : */
