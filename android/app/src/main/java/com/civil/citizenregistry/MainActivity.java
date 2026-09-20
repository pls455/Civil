package com.civil.citizenregistry;

import android.os.Bundle;
import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL = "civil/mdb";
  private static final String TAG = "CivilMdb";

  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
      .setMethodCallHandler((call, result) -> {
        if (!"importMdb".equals(call.method)) {
          result.notImplemented();
          return;
        }
        String sourcePath = call.argument("sourcePath");
        String outputPath = call.argument("outputPath");
        if (sourcePath == null || outputPath == null) {
          result.error("ARGUMENT", "sourcePath/outputPath required", null);
          return;
        }

        new Thread(() -> {
          try {
            Log.i(TAG, "Import started. source=" + sourcePath + " output=" + outputPath);
            MdbImporter.ImportStats stats = MdbImporter.importToSqlite(sourcePath, outputPath);
            Log.i(TAG, "Import completed. tables=" + stats.tables + " rows=" + stats.rows);
            runOnUiThread(() -> result.success(stats.toMap()));
          } catch (Throwable t) {
            Log.e(TAG, "MDB import failed", t);
            String message = t.getClass().getSimpleName() + ": " + (t.getMessage() == null ? "unknown error" : t.getMessage());
            runOnUiThread(() -> result.error("MDB_IMPORT", message, null));
          }
        }, "mdb-import").start();
      });
  }
}
