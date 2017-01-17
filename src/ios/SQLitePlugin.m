/*
 * Copyright (c) 2012-2016: Christopher J. Brody (aka Chris Brody)
 * Copyright (C) 2011 Davide Bertola
 *
 * License for this version: GPL v3 (http://www.gnu.org/licenses/gpl.txt) or commercial license.
 * Contact for commercial license: info@litehelpers.net
 */

#import "SQLitePlugin.h"

#import "sqlite3.h"

#include <regex.h>

// NOTE: This is now broken by cordova-ios 4.0, see:
// https://issues.apache.org/jira/browse/CB-9638
// Solution is to use NSJSONSerialization instead.
#ifdef READ_BLOB_AS_BASE64
#import <Cordova/NSData+Base64.h>
#endif

static void
sqlite_regexp(sqlite3_context * context, int argc, sqlite3_value ** values) {
    if ( argc < 2 ) {
        sqlite3_result_error(context, "SQL function regexp() called with missing arguments.", -1);
        return;
    }

    char * reg = (char *)sqlite3_value_text(values[0]);
    char * text = (char *)sqlite3_value_text(values[1]);

    if ( argc != 2 || reg == 0 || text == 0) {
        sqlite3_result_error(context, "SQL function regexp() called with invalid arguments.", -1);
        return;
    }

    int ret;
    regex_t regex;

    ret = regcomp(&regex, reg, REG_EXTENDED | REG_NOSUB);
    if ( ret != 0 ) {
        sqlite3_result_error(context, "error compiling regular expression", -1);
        return;
    }

    ret = regexec(&regex, text , 0, NULL, 0);
    regfree(&regex);

    sqlite3_result_int(context, (ret != REG_NOMATCH));
}


@implementation SQLitePlugin

@synthesize openDBs;
@synthesize appDBPaths;

-(void)pluginInitialize
{
    NSLog(@"Initializing SQLitePlugin");

    {
        openDBs = [NSMutableDictionary dictionaryWithCapacity:0];
        appDBPaths = [NSMutableDictionary dictionaryWithCapacity:0];
#if !__has_feature(objc_arc)
        [openDBs retain];
        [appDBPaths retain];
#endif

        NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
        NSLog(@"Detected docs path: %@", docs);
        [appDBPaths setObject: docs forKey:@"docs"];

        NSString *libs = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
        NSLog(@"Detected Library path: %@", libs);
        [appDBPaths setObject: libs forKey:@"libs"];

        NSString *nosync = [libs stringByAppendingPathComponent:@"LocalDatabase"];
        NSError *err;
        if ([[NSFileManager defaultManager] fileExistsAtPath: nosync])
        {
            NSLog(@"no cloud sync at path: %@", nosync);
            [appDBPaths setObject: nosync forKey:@"nosync"];
        }
        else
        {
            if ([[NSFileManager defaultManager] createDirectoryAtPath: nosync withIntermediateDirectories:NO attributes: nil error:&err])
            {
                NSURL *nosyncURL = [ NSURL fileURLWithPath: nosync];
                if (![nosyncURL setResourceValue: [NSNumber numberWithBool: YES] forKey: NSURLIsExcludedFromBackupKey error: &err])
                {
                    NSLog(@"IGNORED: error setting nobackup flag in LocalDatabase directory: %@", err);
                }
                NSLog(@"no cloud sync at path: %@", nosync);
                [appDBPaths setObject: nosync forKey:@"nosync"];
            }
            else
            {
                // fallback:
                NSLog(@"WARNING: error adding LocalDatabase directory: %@", err);
                [appDBPaths setObject: libs forKey:@"nosync"];
            }
        }
    }
}

-(id) getDBPath:(NSString *)dbFile at:(NSString *)atkey {
    if (dbFile == NULL) {
        return NULL;
    }

    NSString *dbdir = [appDBPaths objectForKey:atkey];
    NSString *dbPath = [dbdir stringByAppendingPathComponent: dbFile];
    return dbPath;
}

// XXX NOTE: This implementation gets _all_ operations working in the background
// and _should_ resolve intermittent problems reported with cordova-ios@4.0.1).
// This implementation _does_ fail certain rapidly repeated
// open-and close and open-and-delete test scenarios.
-(void)executeInBackground: (CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        @synchronized(self) {
            if ([command.methodName isEqualToString: @"open"])
                [self openNow: command];
            else if ([command.methodName isEqualToString: @"close"])
                [self closeNow: command];
            else if ([command.methodName isEqualToString: @"delete"])
                [self deleteNow: command];
            else if ([command.methodName isEqualToString: @"backgroundExecuteSqlBatch"])
                [self executeSqlBatchNow: command];
        }
    }];
}

-(void)open: (CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        [self executeInBackground: command];
    }];
}

-(void)openNow: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSMutableDictionary *options = [command.arguments objectAtIndex:0];

    NSString *dbfilename = [options objectForKey:@"name"];

    NSString *dblocation = [options objectForKey:@"dblocation"];
    if (dblocation == NULL) dblocation = @"docs";
    //NSLog(@"using db location: %@", dblocation);

    NSString *dbname = [self getDBPath:dbfilename at:dblocation];

    if (dbname == NULL) {
        NSLog(@"No db name specified for open");
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"You must specify database name"];
    }
    else {
        NSValue *dbPointer = [openDBs objectForKey:dbfilename];

        if (dbPointer != NULL) {
            NSLog(@"Reusing existing database connection for db name %@", dbfilename);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Database opened"];
        } else {
            const char *name = [dbname UTF8String];
            sqlite3 *db;

            NSLog(@"open full db path: %@", dbname);

            /* Option to create database from resource (pre-populated) if it does not exist: */
            if (![[NSFileManager defaultManager] fileExistsAtPath: dbname]) {
                NSString * createFromResource = [options objectForKey:@"createFromResource"];
                if (createFromResource != NULL)
                    [self createFromResource: dbfilename withDbname: dbname];
            }

            if (sqlite3_open(name, &db) != SQLITE_OK) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Unable to open DB"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId: command.callbackId];
                return;
            } else {
                sqlite3_create_function(db, "REGEXP", 2, SQLITE_ANY, NULL, &sqlite_regexp, NULL, NULL);

                // for SQLCipher version:
                // NSString *dbkey = [options objectForKey:@"key"];
                // const char *key = NULL;
                // if (dbkey != NULL) key = [dbkey UTF8String];
                // if (key != NULL) sqlite3_key(db, key, strlen(key));

                // Attempt to read the SQLite master table [to support SQLCipher version]:
                if(sqlite3_exec(db, (const char*)"SELECT count(*) FROM sqlite_master;", NULL, NULL, NULL) == SQLITE_OK) {
                    dbPointer = [NSValue valueWithPointer:db];
                    [openDBs setObject: dbPointer forKey: dbfilename];
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"a1i"];
                } else {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Unable to open DB with key"];
                    // XXX TODO: close the db handle & [perhaps] remove from openDBs!!
                }
            }
        }
    }

    if (sqlite3_threadsafe()) {
        NSLog(@"Good news: SQLite is thread safe!");
    }
    else {
        NSLog(@"Warning: SQLite is not thread safe.");
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId: command.callbackId];

    // NSLog(@"open cb finished ok");
}

-(void) createFromResource: (NSString *)dbfile withDbname:(NSString *)dbname {
    // IMPLEMENTATION based on various sources:
    NSString * bundleRoot = [[NSBundle mainBundle] resourcePath];

    NSString * www = [bundleRoot stringByAppendingPathComponent:@"www"];
    NSString * prepopulatedDb = [www stringByAppendingPathComponent: dbfile];
    // NSLog(@"Look for pre-populated DB at: %@", prepopulatedDb);

    if ([[NSFileManager defaultManager] fileExistsAtPath:prepopulatedDb]) {
        NSLog(@"Found prepopulated DB: %@", prepopulatedDb);
        NSError * error;
        BOOL success = [[NSFileManager defaultManager] copyItemAtPath:prepopulatedDb toPath:dbname error:&error];

        if(success)
            NSLog(@"Copied pre-populated DB content to: %@", dbname);
        else
            NSLog(@"Unable to copy pre-populated DB file: %@", [error localizedDescription]);
    }
}

-(void) close: (CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        [self executeInBackground: command];
    }];
}

-(void)closeNow: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSMutableDictionary *options = [command.arguments objectAtIndex:0];

    NSString *dbFileName = [options objectForKey:@"path"];

    if (dbFileName == NULL) {
        // Should not happen:
        NSLog(@"No db name specified for close");
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"You must specify database path"];
    } else {
        NSValue *val = [openDBs objectForKey:dbFileName];
        sqlite3 *db = [val pointerValue];

        if (db == NULL) {
            // Should not happen:
            NSLog(@"close: db name was not open: %@", dbFileName);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Specified db was not open"];
        }
        else {
            NSLog(@"close db name: %@", dbFileName);
            sqlite3_close (db);
            [openDBs removeObjectForKey:dbFileName];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"DB closed"];
        }
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId: command.callbackId];
}

-(void) delete: (CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        [self executeInBackground: command];
    }];
}

-(void)deleteNow: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSMutableDictionary *options = [command.arguments objectAtIndex:0];

    NSString *dbFileName = [options objectForKey:@"path"];

    NSString *dblocation = [options objectForKey:@"dblocation"];
    if (dblocation == NULL) dblocation = @"docs";

    if (dbFileName==NULL) {
        // Should not happen:
        NSLog(@"No db name specified for delete");
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"You must specify database path"];
    } else {
        NSString *dbPath = [self getDBPath:dbFileName at:dblocation];

        if ([[NSFileManager defaultManager]fileExistsAtPath:dbPath]) {
            NSLog(@"delete full db path: %@", dbPath);
            [[NSFileManager defaultManager]removeItemAtPath:dbPath error:nil];
            [openDBs removeObjectForKey:dbFileName];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"DB deleted"];
        } else {
            NSLog(@"delete: db was not found: %@", dbPath);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The database does not exist on that path"];
        }
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


-(void) backgroundExecuteSqlBatch: (CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        [self executeSqlBatchNow: command];
    }];
}

-(void) executeSqlBatchNow: (CDVInvokedUrlCommand*)command
{
    NSMutableDictionary *options = [command.arguments objectAtIndex:0];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:0];
    NSMutableDictionary *dbargs = [options objectForKey:@"dbargs"];
    NSNumber *flen = [options objectForKey:@"flen"];
    NSMutableArray *flatlist = [options objectForKey:@"flatlist"];
    int sc = [flen integerValue];

    NSString *dbFileName = [dbargs objectForKey:@"dbname"];

    CDVPluginResult* pluginResult;

    int ai = 0;

    @synchronized(self) {
        for (int i=0; i<sc; ++i) {
            NSString *sql = [flatlist objectAtIndex:(ai++)];
            NSNumber *pc = [flatlist objectAtIndex:(ai++)];
            int params_count = [pc integerValue];

            [self executeSql:sql withParams:flatlist first:ai count:params_count onDatabaseName:dbFileName results:results];
            ai += params_count;
        }

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:results];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)executeSql: (NSString*)sql withParams: (NSMutableArray*)params first: (int)first count:(int)params_count onDatabaseName: (NSString*)dbFileName results: (NSMutableArray*)results
{
#if 0 // XXX TODO check in executeSqlBatch: [should NEVER occur]:
    if (dbFileName == NULL) {
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"You must specify database path"];
    }
#endif

    NSValue *dbPointer = [openDBs objectForKey:dbFileName];

#if 0 // XXX TODO check in executeSqlBatch: [should NEVER occur]:
    if (dbPointer == NULL) {
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No such database, you must open it first"];
    }
#endif

    sqlite3 *db = [dbPointer pointerValue];

    const char *sql_stmt = [sql UTF8String];
    NSDictionary *error = nil;
    sqlite3_stmt *statement;
    int result, i, column_type, count;
    int previousRowsAffected, nowRowsAffected, diffRowsAffected;
    long long nowInsertId;
    BOOL keepGoing = YES;
    BOOL hasInsertId;

    NSMutableArray *resultRows = [NSMutableArray arrayWithCapacity:0];
    NSMutableDictionary *entry;
    NSObject *columnValue;
    NSString *columnStringValue;
    NSString *columnName;
    NSObject *insertId;
    NSObject *rowsAffected;

    hasInsertId = NO;
    previousRowsAffected = sqlite3_total_changes(db);

    if (sqlite3_prepare_v2(db, sql_stmt, -1, &statement, NULL) != SQLITE_OK) {
        error = [SQLitePlugin captureSQLiteErrorFromDb:db];
        keepGoing = NO;
    } else if (params != NULL) {
        for (int b = 0; b < params_count; b++) {
            [self bindStatement:statement withArg:[params objectAtIndex:(first+b)] atIndex:(b+1)];
        }
    }

    BOOL hasRows = NO;

    while (keepGoing) {
        result = sqlite3_step (statement);
        switch (result) {

            case SQLITE_ROW:
                if (!hasRows) [results addObject:@"okrows"];
                hasRows = YES;
                i = 0;
                entry = [NSMutableDictionary dictionaryWithCapacity:0];
                count = sqlite3_column_count(statement);

                [results addObject:[NSNumber numberWithInt:count]];

                while (i < count) {
                    columnValue = nil;
                    columnName = [NSString stringWithFormat:@"%s", sqlite3_column_name(statement, i)];

                    [results addObject:columnName];

                    column_type = sqlite3_column_type(statement, i);
                    switch (column_type) {
                        case SQLITE_INTEGER:
                            columnValue = [NSNumber numberWithLongLong: sqlite3_column_int64(statement, i)];
                            break;
                        case SQLITE_FLOAT:
                            columnValue = [NSNumber numberWithDouble: sqlite3_column_double(statement, i)];
                            break;
                        case SQLITE_BLOB:
                        case SQLITE_TEXT:
                            columnStringValue = [[NSString alloc] initWithBytes:(char *)sqlite3_column_text(statement, i)
                                                                   length:sqlite3_column_bytes(statement, i)
                                                                 encoding:NSUTF8StringEncoding];
#if !__has_feature(objc_arc)
                            [columnStringValue autorelease];
#endif
                            columnValue = [columnStringValue stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                            break;
                        case SQLITE_NULL:
                        // just in case (should not happen):
                        default:
                            columnValue = [NSNull null];
                            break;
                    }

                    [results addObject:columnValue];

                    i++;
                }
                [resultRows addObject:entry];
                break;

            case SQLITE_DONE:
                if (hasRows) [results addObject:@"endrows"];
                nowRowsAffected = sqlite3_total_changes(db);
                diffRowsAffected = nowRowsAffected - previousRowsAffected;
                rowsAffected = [NSNumber numberWithInt:diffRowsAffected];
                nowInsertId = sqlite3_last_insert_rowid(db);
                if (nowRowsAffected > 0 && nowInsertId != 0) {
                    hasInsertId = YES;
                    insertId = [NSNumber numberWithLongLong:nowInsertId];
                }
                else insertId = [NSNumber numberWithLongLong:-1];
                keepGoing = NO;
                break;

            default:
                error = [SQLitePlugin captureSQLiteErrorFromDb:db];
                keepGoing = NO;
        }
    }

    sqlite3_finalize (statement);

    if (error) {
        /* add error with result.message: */

        [results addObject:@"error"];
        [results addObject:[error objectForKey:@"code"]];
        [results addObject:[error objectForKey:@"sqliteCode"]];
        [results addObject:[error objectForKey:@"message"]];

        return;
    }

    if (!hasRows) {
        [results addObject:@"ch2"];
        [results addObject:rowsAffected];
        [results addObject:insertId];
    }
}

-(void)bindStatement:(sqlite3_stmt *)statement withArg:(NSObject *)arg atIndex:(int)argIndex
{
    if ([arg isEqual:[NSNull null]]) {
        sqlite3_bind_null(statement, argIndex);
    } else if ([arg isKindOfClass:[NSNumber class]]) {
        NSNumber *numberArg = (NSNumber *)arg;
        const char *numberType = [numberArg objCType];
        if (strcmp(numberType, @encode(int)) == 0 ||
            strcmp(numberType, @encode(long long int)) == 0) {
            sqlite3_bind_int64(statement, argIndex, [numberArg longLongValue]);
        } else if (strcmp(numberType, @encode(double)) == 0) {
            sqlite3_bind_double(statement, argIndex, [numberArg doubleValue]);
        } else {
            sqlite3_bind_text(statement, argIndex, [[arg description] UTF8String], -1, SQLITE_TRANSIENT);
        }
    } else { // NSString
        NSString *stringArg;

        if ([arg isKindOfClass:[NSString class]]) {
            stringArg = (NSString *)arg;
        } else {
            stringArg = [arg description]; // convert to text
        }

        {
            NSData *data = [stringArg dataUsingEncoding:NSUTF8StringEncoding];
            sqlite3_bind_text(statement, argIndex, data.bytes, (int)data.length, SQLITE_TRANSIENT);
        }
    }
}

-(void)dealloc
{
    int i;
    NSArray *keys = [openDBs allKeys];
    NSValue *pointer;
    NSString *key;
    sqlite3 *db;

    /* close db the user forgot */
    for (i=0; i<[keys count]; i++) {
        key = [keys objectAtIndex:i];
        pointer = [openDBs objectForKey:key];
        db = [pointer pointerValue];
        sqlite3_close (db);
    }

#if !__has_feature(objc_arc)
    [openDBs release];
    [appDBPaths release];
    [super dealloc];
#endif
}

+(NSDictionary *)captureSQLiteErrorFromDb:(struct sqlite3 *)db
{
    int code = sqlite3_errcode(db);
    int webSQLCode = [SQLitePlugin mapSQLiteErrorCode:code];
#if 0 // XXX NOT SUPPORTED IN THIS VERSION:
    int extendedCode = sqlite3_extended_errcode(db);
#endif
    const char *message = sqlite3_errmsg(db);

    NSMutableDictionary *error = [NSMutableDictionary dictionaryWithCapacity:4];

    [error setObject:[NSNumber numberWithInt:webSQLCode] forKey:@"code"];
    [error setObject:[NSString stringWithUTF8String:message] forKey:@"message"];

    [error setObject:[NSNumber numberWithInt:code] forKey:@"sqliteCode"];
#if 0 // XXX NOT SUPPORTED IN THIS VERSION:
    [error setObject:[NSNumber numberWithInt:extendedCode] forKey:@"sqliteExtendedCode"];
    [error setObject:[NSString stringWithUTF8String:message] forKey:@"sqliteMessage"];
#endif

    return error;
}

+(int)mapSQLiteErrorCode:(int)code
{
    // map the sqlite error code to
    // the websql error code
    switch(code) {
        case SQLITE_ERROR:
            return SYNTAX_ERR;
        case SQLITE_FULL:
            return QUOTA_ERR;
        case SQLITE_CONSTRAINT:
            return CONSTRAINT_ERR;
        default:
            return UNKNOWN_ERR;
    }
}

@end /* vim: set expandtab : */
