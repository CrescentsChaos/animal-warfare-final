// scripts/trainer_server.dart
//
// Standalone Dart HTTP Server for the HTML Trainer UI.
// Run with: dart run scripts/trainer_server.dart

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:image/image.dart' as img;

// Since we are bypassing Flutter, we will use the exact same logic as
// scratch/train_features.dart which uses sqflite_common_ffi and raw image bytes.
import '../scratch/train_features.dart' as train_cli;

void main() async {
  // Initialize FFI
  sqfliteFfiInit();

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);

  await for (HttpRequest request in server) {
    // Enable CORS just in case
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Origin, Content-Type',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      continue;
    }

    if (request.method == 'GET' && request.uri.path == '/') {
      // Serve HTML
      final htmlFile = File(
        p.join(Directory.current.path, 'assets', 'trainer.html'),
      );
      if (await htmlFile.exists()) {
        request.response.headers.contentType = ContentType.html;
        await request.response.addStream(htmlFile.openRead());
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('trainer.html not found in assets/');
      }
      await request.response.close();
    } else if (request.method == 'POST' && request.uri.path == '/train') {
      // Handle training
      await _handleTrain(request);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not found');
      await request.response.close();
    }
  }
}

Future<void> _handleTrain(HttpRequest request) async {
  try {
    final content = await utf8.decoder.bind(request).join();
    final data = jsonDecode(content);

    final sciName = data['scientificName'] as String?;
    final images = data['images'] as List<dynamic>?;
    final animalClass = data['animalClass'] as String?;
    final diet = data['diet'] as String?;
    final weight = (data['weight'] as num?)?.toDouble();

    if (sciName == null ||
        sciName.isEmpty ||
        images == null ||
        images.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(
        jsonEncode({'error': 'Missing scientificName or images'}),
      );
      await request.response.close();
      return;
    }

    final absoluteDbPath = p.join(
      Directory.current.path,
      'assets',
      'ml',
      'sprite_features.db',
    );
    var db = await databaseFactoryFfi.openDatabase(
      absoluteDbPath,
      options: OpenDatabaseOptions(version: 1),
    );

    // Try to find the organism name in Organisms.json
    String organismName = sciName;
    try {
      final jsonFile = File(
        p.join(Directory.current.path, 'assets', 'Organisms.json'),
      );
      if (await jsonFile.exists()) {
        final orgList =
            jsonDecode(await jsonFile.readAsString()) as List<dynamic>;
        final org = orgList.firstWhere(
          (o) =>
              o['scientificName']?.toString().toLowerCase() ==
              sciName.toLowerCase(),
          orElse: () => null,
        );
        if (org != null) {
          organismName = org['name'];
        }
      }
    } catch (_) {}

    int successCount = 0;
    int failCount = 0;
    List<Map<String, String>> logs = [];

    for (int i = 0; i < images.length; i++) {
      final imgObj = images[i];
      final fileName = imgObj['name'];
      final b64Data = imgObj['data'];

      logs.add({
        'msg': 'Processing [$i/${images.length}]: $fileName...',
        'type': 'info',
      });

      try {
        final bytes = base64Decode(b64Data);
        final decoded = img.decodeImage(bytes);
        if (decoded == null) throw Exception('Failed to decode image');

        // Use the exact same extraction logic from the CLI script we wrote
        final newFeatures = train_cli.extractFeatures(decoded, organismName);

        // Upsert
        await train_cli.upsertFeatureToDb(
          db,
          organismName,
          scientificName: sciName,
          newFeatures: newFeatures,
          animalClass: animalClass,
          diet: diet,
          weight: weight,
        );

        logs.add({'msg': '  -> Success! DB updated.', 'type': 'success'});
        successCount++;
      } catch (e) {
        logs.add({'msg': '  -> FAILED: $e', 'type': 'error'});
        failCount++;
      }
    }

    await db.close();

    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'successCount': successCount,
        'failCount': failCount,
        'logs': logs,
      }),
    );
    await request.response.close();
  } catch (e) {
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.write(jsonEncode({'error': e.toString()}));
    await request.response.close();
  }
}
