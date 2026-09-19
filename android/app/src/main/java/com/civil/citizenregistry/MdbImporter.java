package com.civil.citizenregistry;

import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteStatement;
import com.healthmarketscience.jackcess.Column;
import com.healthmarketscience.jackcess.Database;
import com.healthmarketscience.jackcess.DatabaseBuilder;
import com.healthmarketscience.jackcess.Table;
import java.io.File;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class MdbImporter {
  private MdbImporter() {}

  public static final class ImportStats {
    public int tables;
    public long rows;
    public final Map<String, List<String>> schema = new LinkedHashMap<>();

    public Map<String, Object> toMap() {
      Map<String, Object> out = new LinkedHashMap<>();
      out.put("tables", tables);
      out.put("rows", rows);
      out.put("schema", schema);
      return out;
    }
  }

  public static ImportStats importToSqlite(String sourcePath, String outputPath) throws Exception {
    System.setProperty("com.healthmarketscience.jackcess.brokenNio", "true");
    System.setProperty("com.healthmarketscience.jackcess.resourcePath", "/res/raw/");
    Thread.currentThread().setContextClassLoader(Database.class.getClassLoader());

    File source = new File(sourcePath);
    if (!source.isFile()) throw new IllegalArgumentException("MDB source does not exist");

    File output = new File(outputPath);
    File parent = output.getParentFile();
    if (parent != null && !parent.exists() && !parent.mkdirs() && !parent.isDirectory()) {
      throw new IllegalStateException("Cannot create SQLite output directory");
    }
    if (output.exists() && !output.delete()) {
      throw new IllegalStateException("Cannot replace temporary SQLite database");
    }

    Database access = null;
    SQLiteDatabase sqlite = null;
    boolean transactionStarted = false;
    ImportStats stats = new ImportStats();

    try {
      access = DatabaseBuilder.open(source);
      sqlite = SQLiteDatabase.openOrCreateDatabase(output, null);
      sqlite.beginTransaction();
      transactionStarted = true;
      sqlite.execSQL("PRAGMA foreign_keys=OFF");
      sqlite.execSQL("PRAGMA synchronous=OFF");
      sqlite.execSQL("CREATE TABLE __civil_import_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)");
      sqlite.execSQL("CREATE TABLE __civil_schema (table_name TEXT NOT NULL, column_name TEXT NOT NULL, column_type TEXT NOT NULL, ordinal INTEGER NOT NULL)");

      for (Table table : access) {
        if (table.isSystem()) continue;
        List<Column> columns = new ArrayList<>();
        for (Column column : table.getColumns()) columns.add(column);
        if (columns.isEmpty()) continue;

        stats.tables++;
        List<String> names = new ArrayList<>();
        for (int i = 0; i < columns.size(); i++) {
          Column column = columns.get(i);
          names.add(column.getName());
          sqlite.execSQL("INSERT INTO __civil_schema(table_name,column_name,column_type,ordinal) VALUES(?,?,?,?)",
              new Object[] {table.getName(), column.getName(), column.getType().name(), i});
        }
        stats.schema.put(table.getName(), names);

        String tableName = quote(table.getName());
        StringBuilder ddl = new StringBuilder("CREATE TABLE ").append(tableName).append(" (");
        for (int i = 0; i < columns.size(); i++) {
          if (i > 0) ddl.append(',');
          Column column = columns.get(i);
          ddl.append(quote(column.getName())).append(' ').append(sqliteType(column));
        }
        ddl.append(')');
        sqlite.execSQL(ddl.toString());

        StringBuilder insert = new StringBuilder("INSERT INTO ").append(tableName).append(" VALUES (");
        for (int i = 0; i < columns.size(); i++) {
          if (i > 0) insert.append(',');
          insert.append('?');
        }
        insert.append(')');

        SQLiteStatement statement = sqlite.compileStatement(insert.toString());
        try {
          for (Map<String, Object> row : table) {
            statement.clearBindings();
            for (int i = 0; i < columns.size(); i++) {
              bind(statement, i + 1, row.get(columns.get(i).getName()));
            }
            statement.executeInsert();
            stats.rows++;
          }
        } finally {
          statement.close();
        }
      }

      sqlite.execSQL("INSERT INTO __civil_import_metadata(key,value) VALUES(?,?)", new Object[] {"format", "civil-mdb-import-v1"});
      sqlite.execSQL("INSERT INTO __civil_import_metadata(key,value) VALUES(?,?)", new Object[] {"source_file_name", source.getName()});
      sqlite.execSQL("INSERT INTO __civil_import_metadata(key,value) VALUES(?,?)", new Object[] {"table_count", Integer.toString(stats.tables)});
      sqlite.execSQL("INSERT INTO __civil_import_metadata(key,value) VALUES(?,?)", new Object[] {"row_count", Long.toString(stats.rows)});
      sqlite.setTransactionSuccessful();
      return stats;
    } catch (Exception e) {
      if (output.exists() && !output.delete()) { }
      throw e;
    } finally {
      if (transactionStarted && sqlite != null && sqlite.inTransaction()) sqlite.endTransaction();
      if (sqlite != null) sqlite.close();
      if (access != null) access.close();
    }
  }

  private static String sqliteType(Column column) {
    String type = column.getType().name();
    if (type.contains("BYTE") || type.contains("SHORT") || type.contains("LONG") || type.contains("INT") || type.contains("COUNTER") || type.contains("YESNO")) return "INTEGER";
    if (type.contains("DOUBLE") || type.contains("FLOAT") || type.contains("DECIMAL") || type.contains("NUMERIC") || type.contains("MONEY")) return "REAL";
    if (type.contains("BINARY") || type.contains("OLE")) return "BLOB";
    return "TEXT";
  }

  private static void bind(SQLiteStatement statement, int index, Object value) {
    if (value == null) statement.bindNull(index);
    else if (value instanceof byte[]) statement.bindBlob(index, (byte[]) value);
    else if (value instanceof Byte || value instanceof Short || value instanceof Integer || value instanceof Long) statement.bindLong(index, ((Number) value).longValue());
    else if (value instanceof Number) statement.bindDouble(index, ((Number) value).doubleValue());
    else if (value instanceof Date) statement.bindString(index, new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).format((Date) value));
    else statement.bindString(index, value.toString());
  }

  private static String quote(String value) {
    return "\"" + value.replace("\"", "\"\"") + "\"";
  }
}
