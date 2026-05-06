class Organism {
  final String name;
  Organism(this.name);
}

class ScanResult {
  final Organism organism;
  final double confidence;
  final Map<String, double> featureScores;
  ScanResult(this.organism, this.confidence, this.featureScores);
}

void main() {
  final results = [
    ScanResult(Organism('Yellow Fish'), 0.9, {'Color': 0.95, 'Shape': 0.7, 'Shade': 0.8}),
    ScanResult(Organism('Orange Fish'), 0.85, {'Color': 0.8, 'Shape': 0.95, 'Shade': 0.7}),
    ScanResult(Organism('Grey Fish'), 0.8, {'Color': 0.5, 'Shape': 0.8, 'Shade': 0.95}),
  ];

  void printResults(String sortBy, List<ScanResult> list) {
    print('--- Sorted by $sortBy ---');
    for (var r in list) {
      print('${r.organism.name}: Conf=${r.confidence}, Clr=${r.featureScores['Color']}, Shp=${r.featureScores['Shape']}, Shd=${r.featureScores['Shade']}');
    }
  }

  void sort(String sortBy) {
    results.sort((a, b) {
      double valA, valB;
      switch (sortBy) {
        case 'Color':
          valA = a.featureScores['Color'] ?? 0;
          valB = b.featureScores['Color'] ?? 0;
          break;
        case 'Shape':
          valA = a.featureScores['Shape'] ?? 0;
          valB = b.featureScores['Shape'] ?? 0;
          break;
        case 'Shade':
          valA = a.featureScores['Shade'] ?? 0;
          valB = b.featureScores['Shade'] ?? 0;
          break;
        default:
          valA = a.confidence;
          valB = b.confidence;
      }
      return valB.compareTo(valA);
    });
  }

  sort('Overall');
  printResults('Overall', results);

  sort('Color');
  printResults('Color', results);

  sort('Shape');
  printResults('Shape', results);

  sort('Shade');
  printResults('Shade', results);
}
