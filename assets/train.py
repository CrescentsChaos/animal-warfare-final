import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import pandas as pd
import json

df = pd.read_csv('assets/manifest.csv')

# Augmentation designed for Shape and Color recognition
datagen = ImageDataGenerator(
    rescale=1./255,
    validation_split=0.2,
    brightness_range=[0.8, 1.2], # Forces color recognition under different lighting
    zoom_range=0.2,               # Forces shape recognition by varying size
    horizontal_flip=True
)

train_gen = datagen.flow_from_dataframe(
    df, x_col='filepath', y_col='name', 
    target_size=(224, 224), batch_size=32, subset='training'
)

# Using a more robust base for fine-grained details
base_model = tf.keras.applications.MobileNetV2(input_shape=(224, 224, 3), include_top=False)
base_model.trainable = True 

# Fine-tuning the top layers to focus on color and shape patterns
for layer in base_model.layers[:-30]:
    layer.trainable = False

model = tf.keras.Sequential([
    base_model,
    tf.keras.layers.GlobalAveragePooling2D(),
    tf.keras.layers.BatchNormalization(), # Stabilizes learning for color/texture
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(len(train_gen.class_indices), activation='softmax')
])

# Use a slightly higher learning rate than before to escape local minima
model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=0.0005), 
    loss='categorical_crossentropy', 
    metrics=['accuracy']
)

# Save mapping
label_map = {v: k for k, v in train_gen.class_indices.items()}
with open('class_indices.json', 'w') as f:
    json.dump(label_map, f)

# Increase epochs: 3,000 species need more "study time"
model.fit(train_gen, epochs=50) 
model.save('animal_recognizer.h5')