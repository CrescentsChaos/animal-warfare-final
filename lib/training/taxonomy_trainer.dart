import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() async {
  print('=== TAXONOMY TRAINING ENGINE v6 (GMM-15 + Color + Structure) ===');
  sqfliteFfiInit();
  var db = await databaseFactoryFfi.openDatabase(
    p.join(Directory.current.path, 'assets', 'ml', 'sprite_features.db'),
  );
  await db.execute('DROP TABLE IF EXISTS taxonomy_profiles');
  await db.execute(
    'CREATE TABLE taxonomy_profiles (id INTEGER PRIMARY KEY AUTOINCREMENT, animal_class TEXT UNIQUE NOT NULL, feature_means TEXT NOT NULL, feature_variances TEXT NOT NULL, sample_count INTEGER NOT NULL, updated_at TEXT NOT NULL DEFAULT (datetime(\'now\')))',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS taxonomy_metadata (key TEXT PRIMARY KEY, data TEXT NOT NULL)',
  );

  final organismsFile = File('assets/Organisms.json');
  final List<dynamic> animalsData = json.decode(
    organismsFile.readAsStringSync(),
  );
  Map<String, List<Map<String, double>>> classSamples = {};

  int count = 0;
  for (var org in animalsData) {
    final name = org['name'];
    final String subfamily = org['subfamily']?.toString().toLowerCase().trim() ?? 'unknown';
    final String family = org['family']?.toString().toLowerCase().trim() ?? 'unknown';
    final String order = org['order']?.toString().toLowerCase().trim() ?? 'unknown';
    final String animalClass = (org['class'] ?? org['animal_class'] ?? 'unknown').toString().toLowerCase().trim();

    String cls = 'unknown';
    if (subfamily != 'unknown' && subfamily.isNotEmpty && subfamily != 'none' && subfamily != 'n/a') {
      cls = subfamily;
    } else if (family != 'unknown' && family.isNotEmpty && family != 'none' && family != 'n/a') {
      cls = family;
    } else if (order != 'unknown' && order.isNotEmpty && order != 'none' && order != 'n/a') {
      cls = order;
    } else if (animalClass != 'unknown' && animalClass.isNotEmpty && animalClass != 'none' && animalClass != 'n/a') {
      cls = animalClass;
    }

    if (cls == 'unknown') {
       cls = name.toString().toLowerCase(); // Fallback to name if everything is unknown (take everything)
    }

    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final file = File('assets/sprites/$slug.png');
    if (!file.existsSync()) continue;
    try {
      final decoded = img.decodeImage(file.readAsBytesSync());
      if (decoded == null) continue;
      final resized = _preprocess(decoded);
      final mask = _buildMask(resized);
      final f = _extractFeatures(resized, mask);
      if (f.isNotEmpty) {
        classSamples.putIfAbsent(cls, () => []).add(f);
        count++;
        if (count % 100 == 0) print('  Processed $count sprites...');
      }
    } catch (e) {}
  }

  final featureKeys = classSamples.values.expand((l) => l).first.keys.toList();
  final gMeans = <String, double>{}, gStds = <String, double>{};
  for (var key in featureKeys) {
    double sum = 0, sumSq = 0;
    int n = 0;
    for (var samples in classSamples.values)
      for (var s in samples) {
        sum += s[key]!;
        sumSq += s[key]! * s[key]!;
        n++;
      }
    gMeans[key] = sum / n;
    gStds[key] = sqrt(
      (sumSq / n) - (gMeans[key]! * gMeans[key]!),
    ).clamp(0.01, 10.0);
  }

  for (var samples in classSamples.values)
    for (var f in samples) {
      for (var k in featureKeys) {
        f[k] = ((f[k]! - gMeans[k]!) / gStds[k]!).clamp(-5.0, 5.0);
      }
    }

  List<Map<String, dynamic>> finalModel = [];
  for (var entry in classSamples.entries) {
    final cls = entry.key;
    final samples = entry.value;
    int k = min(samples.length ~/ 8, 15).clamp(1, 15);
    final clusters = _kMeans(samples, k);
    for (int i = 0; i < clusters.length; i++) {
      if (clusters[i].isEmpty) continue;
      Map<String, double> ms = {}, vs = {};
      for (var k in featureKeys) {
        double sum = 0, sumSq = 0;
        for (var s in clusters[i]) {
          sum += s[k]!;
          sumSq += s[k]! * s[k]!;
        }
        ms[k] = sum / clusters[i].length;
        vs[k] = ((sumSq / clusters[i].length) - (ms[k]! * ms[k]!) + 0.02).clamp(
          0.01,
          10.0,
        );
      }
      finalModel.add({
        'class': cls,
        'means': ms,
        'variances': vs,
        'count': clusters[i].length,
      });
      await db.insert('taxonomy_profiles', {
        'animal_class': '${cls}_$i',
        'feature_means': jsonEncode(ms),
        'feature_variances': jsonEncode(vs),
        'sample_count': clusters[i].length,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
  await db.insert('taxonomy_metadata', {
    'key': 'global_stats',
    'data': jsonEncode({'means': gMeans, 'stdDevs': gStds}),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  await db.close();
  // _validate(finalModel, gMeans, gStds);
}

img.Image _preprocess(img.Image s) {
  final d = max(s.width, s.height);
  final c = img.Image(width: d, height: d, numChannels: 4);
  img.fill(c, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(c, s, dstX: (d - s.width) ~/ 2, dstY: (d - s.height) ~/ 2);
  return img.copyResize(c, width: 400, height: 400);
}

List<bool> _buildMask(img.Image i) =>
    List.generate(160000, (idx) => i.getPixel(idx % 400, idx ~/ 400).a >= 128);

Map<String, double> _extractFeatures(img.Image r, List<bool> m) {
  int minX = 400, maxX = 0, minY = 400, maxY = 0, n = 0;
  final hb = <String, double>{};
  for (int i = 0; i < 36; i++) {
    hb['h${i * 10}'] = 0;
  }
  hb['hWhite'] = 0;
  hb['hBlack'] = 0;
  hb['hGrey'] = 0;

  for (int y = 0; y < 400; y++)
    for (int x = 0; x < 400; x++) {
      if (m[y * 400 + x]) {
        n++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        final p = r.getPixel(x, y);
        final hsv = _rgbToHsv(p.r.toInt(), p.g.toInt(), p.b.toInt());
        if (hsv[2] < 0.15) {
          hb['hBlack'] = hb['hBlack']! + 1;
        } else if (hsv[1] < 0.15) {
          if (hsv[2] > 0.8) {
            hb['hWhite'] = hb['hWhite']! + 1;
          } else {
            hb['hGrey'] = hb['hGrey']! + 1;
          }
        } else
          hb['h${(hsv[0] / 10).floor().clamp(0, 35) * 10}'] =
              hb['h${(hsv[0] / 10).floor().clamp(0, 35) * 10}']! + 1;
      }
    }
  if (n == 0) return {};
  hb.forEach((k, v) => hb[k] = v / n);

  final w = maxX - minX + 1, h = maxY - minY + 1;
  final f = Map<String, double>.from(hb);
  f['aspectRatio'] = w / h;
  f['solidity'] = n / (w * h);
  f['bilateralSym'] = _calcSym(m, minY, maxY, minX, maxX, w);
  f['yCentroid'] = _centroidY(m, minY, maxY, minX, maxX, n) / h;
  f['upperWidthRatio'] =
      _maxWidthInRegion(m, minY, minY + h ~/ 3, minX, maxX) / w;
  f['midWidthRatio'] =
      _maxWidthInRegion(m, minY + h ~/ 3, minY + 2 * h ~/ 3, minX, maxX) / w;
  f['lowerWidthRatio'] =
      _maxWidthInRegion(m, minY + 2 * h ~/ 3, maxY, minX, maxX) / w;
  return f;
}

List<double> _rgbToHsv(int r, int g, int b) {
  double rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
  double m = max(rf, max(gf, bf)), mi = min(rf, min(gf, bf)), d = m - mi;
  double h = 0, s = m == 0 ? 0 : d / m, v = m;
  if (d != 0) {
    if (m == rf) {
      h = (gf - bf) / d + (gf < bf ? 6 : 0);
    } else if (m == gf)
      h = (bf - rf) / d + 2;
    else
      h = (rf - gf) / d + 4;
    h /= 6;
  }
  return [h * 360, s, v];
}

double _calcSym(List<bool> m, int minY, int maxY, int minX, int maxX, int w) {
  int matches = 0, total = 0;
  for (int y = minY; y <= maxY; y++)
    for (int x = minX; x < minX + w ~/ 2; x++) {
      total++;
      if (m[y * 400 + x] == m[y * 400 + (maxX - (x - minX))]) matches++;
    }
  return matches / (total > 0 ? total : 1);
}

double _centroidY(List<bool> m, int minY, int maxY, int minX, int maxX, int n) {
  double sumY = 0;
  for (int y = minY; y <= maxY; y++)
    for (int x = minX; x <= maxX; x++) {
      if (m[y * 400 + x]) sumY += y;
    }
  return sumY / n - minY;
}

double _maxWidthInRegion(List<bool> m, int y1, int y2, int minX, int maxX) {
  int maxW = 0;
  for (int y = y1; y <= y2; y++) {
    int rw = 0;
    for (int x = minX; x <= maxX; x++) {
      if (m[y * 400 + x]) rw++;
    }
    if (rw > maxW) maxW = rw;
  }
  return maxW.toDouble();
}

String _normalizeClass(String c) {
  for (var k in [
    'mammal',
    'bird',
    'fish',
    'insect',
    'reptile',
    'amphibian',
    'arachnid',
    'crustacean',
    'mollusk',
    'cnidarian',
  ]) {
    if (c.contains(k)) return k;
  }
  return 'otherInvertebrate';
}

List<List<Map<String, double>>> _kMeans(List<Map<String, double>> s, int k) {
  final centroids = List.generate(
    k,
    (i) => Map<String, double>.from(s[i % s.length]),
  );
  final clusters = List.generate(k, (_) => <Map<String, double>>[]);
  for (int iter = 0; iter < 15; iter++) {
    for (var c in clusters) {
      c.clear();
    }
    for (var x in s) {
      int bk = 0;
      double md = double.infinity;
      for (int i = 0; i < k; i++) {
        double d = 0;
        centroids[i].forEach((k, v) => d += pow((x[k] ?? 0) - v, 2));
        if (d < md) {
          md = d;
          bk = i;
        }
      }
      clusters[bk].add(x);
    }
    for (int i = 0; i < k; i++) {
      if (clusters[i].isEmpty) continue;
      Map<String, double> next = {};
      centroids[i].forEach((k, _) {
        double sum = 0;
        for (var x in clusters[i]) {
          sum += x[k] ?? 0;
        }
        next[k] = sum / clusters[i].length;
      });
      centroids[i] = next;
    }
  }
  return clusters;
}

void _validate(
  List<Map<String, dynamic>> m,
  Map<String, double> gM,
  Map<String, double> gS,
) {
  final ts = [
    ['asiatic_lion', 'mammal'],
    ['red_panda', 'mammal'],
    ['peregrine_falcon', 'bird'],
    ['tawny_eagle', 'bird'],
    ['zebra_lionfish', 'fish'],
    ['reef_manta_ray', 'fish'],
    ['monarch_butterfly', 'insect'],
    ['atlas_beetle', 'insect'],
    ['african_spurred_tortoise', 'reptile'],
    ['emperor_scorpion', 'arachnid'],
    ['lion_s_mane_jellyfish', 'cnidarian'],
    ['coconut_octopus', 'mollusk'],
    ['african_bullfrog', 'amphibian'],
  ];
  int c = 0;
  for (var t in ts) {
    final slug = t[0], exp = t[1];
    final file = File('assets/sprites/$slug.png');
    if (!file.existsSync()) continue;
    final f = _extractFeatures(
      _preprocess(img.decodeImage(file.readAsBytesSync())!),
      _buildMask(_preprocess(img.decodeImage(file.readAsBytesSync())!)),
    );
    if (f.isEmpty) continue;
    f.forEach((k, v) => f[k] = ((v - gM[k]!) / gS[k]!).clamp(-5, 5));
    String bc = 'unknown';
    double bs = double.negativeInfinity;
    for (var mod in m) {
      double s = 0;
      (mod['means'] as Map<String, double>).forEach(
        (k, mean) =>
            s -= (0.5 * pow(f[k]! - mean, 2) / (mod['variances'][k] ?? 0.1)),
      );
      if (s > bs) {
        bs = s;
        bc = mod['class'];
      }
    }
    if (bc == exp) c++;
    print('  $slug: $bc (${bc == exp ? "✓" : "✗ expected $exp"})');
  }
  print('\nAccuracy: ${(c / ts.length * 100).toStringAsFixed(1)}%');
}
