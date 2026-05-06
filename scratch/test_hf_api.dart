import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing Hugging Face Inference API...');
  
  // Using a general ViT model for testing
  final model = 'google/vit-base-patch16-224';
  final url = Uri.parse('https://api-inference.huggingface.co/models/$model');
  
  final imageFile = File('C:/Users/USER/.gemini/antigravity/brain/9e40a678-10f7-4c89-a30a-7b418f7a3012/media__1778087704438.png');
  if (!imageFile.existsSync()) {
    print('Image file not found!');
    return;
  }

  try {
    final bytes = await imageFile.readAsBytes();
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/octet-stream',
        // 'Authorization': 'Bearer YOUR_HF_TOKEN', // Optional for limited use
      },
      body: bytes,
    ).timeout(Duration(seconds: 30));

    print('Status Code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      print('Results:');
      for (var result in data) {
        print('- ${result['label']}: ${(result['score'] * 100).toStringAsFixed(2)}%');
      }
    } else {
      print('Response Body: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
