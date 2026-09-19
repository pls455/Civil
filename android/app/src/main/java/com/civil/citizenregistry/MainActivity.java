package com.civil.citizenregistry;

import android.os.Bundle;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL = "civil/mdb";
  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
      .setMethodCallHandler((call, result) -> {
        if (!"importMdb".equals(call.method)) { result.notImplemented(); return; }
        String sourcePath = call.argument("sourcePath");
        String outputPath = call.argument("outputPath");
        if (sourcePath == null || outputPath == null) {
          result.error("ARGUMENT", "sourcePath/outputPath required", null); return;
        }
        new Thread(() -> {
          try {
            MdbImporter.ImportStats stats = MdbImporter.importToSqlite(sourcePath, outputPath);
            runOnUiThread(() -> result.success(stats.toMap()));
          } catch (Exception e) {
            runOnUiThread(() -> result.error("MDB_IMPORT", e.getMessage(), null));
          }
        }, "mdb-import").start();
      });
  }
}
