import tensorflow as tf
import numpy as np
import sqlite3
import json
from tensorflow.keras.preprocessing import image

def predict_animal(img_path, model_path, label_map_path, db_path):
    model = tf.keras.models.load_model(model_path)
    with open(label_map_path, 'r') as f:
        label_map = json.load(f)
    
    img = image.load_img(img_path, target_size=(224, 224))
    img_array = image.img_to_array(img) / 255.0
    img_array = np.expand_dims(img_array, axis=0)
    
    prediction = model.predict(img_array)
    predicted_index = str(np.argmax(prediction))
    confidence = np.max(prediction)
    
    # AI now returns the specific Name (e.g., 'Whale Shark')
    animal_name = label_map[predicted_index]

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # We now query by name to get the correct species data
    cursor.execute("SELECT * FROM Animals WHERE name = ?", (animal_name,))
    row = cursor.fetchone()
    
    columns = [description[0] for description in cursor.description]
    conn.close()

    return animal_name, confidence, dict(zip(columns, row)) if row else None

# Run and Display
name=input("Enter animal name: ")
name, conf, data = predict_animal(
    'assets/sprites/'+name+'.png', 
    'animal_recognizer.h5', 
    'class_indices.json', 
    'assets/Organisms.db'
)

if data:
    print(f"\n=== SPECIES IDENTIFIED ===")
    print(f"Name:       {name}")
    print(f"Confidence: {conf*100:.2f}%")
    print("-" * 30)
    print(f"Class:      {data.get('class', 'N/A')}")
    print(f"Order:      {data.get('order', 'N/A')}")
    print(f"Family:     {data.get('family', 'N/A')}")
    print(f"Subfamily:  {data.get('subfamily', 'N/A')}")
    print(f"Scientific: {data.get('scientific_name', 'N/A')}") 
    print("-" * 30)
    print(f"Diet:       {data.get('diet', 'N/A')}")
    print(f"Habitat:    {data.get('habitat', 'N/A')}")