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
      out.put("tables", tables); out.put("rows", rows); out.put("schema", schema);
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
    if (output.exists() && !output.delete()) throw new IllegalStateException("Cannot replace temporary database");
    File parent = output.getParentFile();
    if (parent != null) parent.mkdirs();

    Database access = DatabaseBuilder.open(source);
    SQLiteDatabase sqlite = SQLiteDatabase.openOrCreateDatabase(output, null);
    ImportStats stats = new ImportStats();

    try {
      sqlite.beginTransaction();
      sqlite.execSQL("PRAGMA foreign_keys=OFF");
      sqlite.execSQL("PRAGMA synchronous=OFF");

      for (Table table : access) {
        if (table.isSystem()) continue;
        List<Column> columns = new ArrayList<>();
        for (Column c : table.getColumns()) columns.add(c);
        if (columns.isEmpty()) continue;
        stats.tables++;
        List<String> names = new ArrayList<>();
        for (Column c : columns) names.add(c.getName());
        stats.schema.put(table.getName(), names);

        final String tableName = quote(table.getName());
        StringBuilder ddl = new StringBuilder("CREATE TABLE ").append(tableName).append(" (");
        for (int i = 0; i < columns.size(); i++) {
          if (i > 0) ddl.append(',');
          Column c = columns.get(i);
          ddl.append(quote(c.getName())).append(' ').append(sqliteType(c));
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
        for (Map<String, Object> row : table) {
          statement.clearBindings();
          for (int i = 0; i < columns.size(); i++) bind(statement, i + 1, row.get(columns.get(i).getName()));
          statement.executeInsert();
          stats.rows++;
        }
        statement.close();
      }
      sqlite.setTransactionSuccessful();
    } catch (Exception e) {
      if (output.exists()) output.delete();
      throw e;
    } finally {
      sqlite.endTransaction();
      sqlite.close();
      access.close();
    }
    return stats;
  }

  private static String sqliteType(Column c) {
    String t = c.getType().name();
    if (t.contains("BYTE") || t.contains("SHORT") || t.contains("LONG") || t.contains("INT") || t.contains("COUNTER") || t.contains("YESNO")) return "INTEGER";
    if (t.contains("DOUBLE") || t.contains("FLOAT") || t.contains("DECIMAL") || t.contains("NUMERIC") || t.contains("MONEY")) return "REAL";
    if (t.contains("BINARY") || t.contains("OLE")) return "BLOB";
    return "TEXT";
  }

  private static void bind(SQLiteStatement s, int index, Object value) {
    if (value == null) s.bindNull(index);
    else if (value instanceof byte[]) s.bindBlob(index, (byte[]) value);
    else if (value instanceof Number) s.bindDouble(index, ((Number) value).doubleValue());
    else if (value instanceof Date) s.bindString(index, new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).format((Date) value));
    else s.bindString(index, value.toString());
  }

  private static String quote(String s) { return "\"" + s.replace("\"", "\"\"") + "\""; }
}
