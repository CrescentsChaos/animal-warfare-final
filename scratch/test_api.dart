import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing iNaturalist API...');
  final url = Uri.parse('https://api.inaturalist.org/v1/computervision/score');
  
  final imageFile = File('C:/Users/USER/.gemini/antigravity/brain/9e40a678-10f7-4c89-a30a-7b418f7a3012/media__1778087704438.png');
  if (!imageFile.existsSync()) {
    print('Image file not found!');
    return;
  }

  try {
    final request = http.MultipartRequest('POST', url);
    request.headers['User-Agent'] = 'iNaturalist/1.0 (com.inaturalist.iNaturalist; build:1; iOS 15.0.0)';
    
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
    ));

    final response = await request.send().timeout(Duration(seconds: 20));
    print('Status Code: ${response.statusCode}');
    final body = await response.stream.bytesToString();
    
    if (response.statusCode == 200) {
      final data = json.decode(body);
      print('Results: ${data['results']?.length} taxa found');
      if (data['results'] != null && data['results'].isNotEmpty) {
        print('Top match: ${data['results'][0]['taxon']['name']}');
      }
    } else {
      print('Response Body: $body');
    }
  } catch (e) {
    print('Error: $e');
  }
}
