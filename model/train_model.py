from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
from keras.preprocessing.image import img_to_array

from tensorflow.keras.utils import to_categorical

from lenet.nn.conv import LeNet
from imutils import paths
import imutils
import matplotlib.pyplot as plt
import numpy as np
import argparse
import cv2
import os

ap = argparse.ArgumentParser()
ap.add_argument('-d', '--dataset', required=True, help='path to the input dataset of faces')
ap.add_argument('-m', '--model', required=True, help='path to output model')
args = vars(ap.parse_args())

data = []
labels = []

for imagePath in sorted(list(paths.list_images(args['dataset']))):
    image = cv2.imread(imagePath)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    image = imutils.resize(image, width=28)
    image = img_to_array(image)
    data.append(image)

    label = imagePath.split(os.path.sep)[-3]
    label = 'smiling' if label == 'positives' else 'not_smiling'
    labels.append(label)

data = np.array(data, dtype='float') / 255.0
labels = np.array(labels)

le = LabelEncoder().fit(labels)
labels = to_categorical(le.transform(labels), 2)

classTotals = labels.sum(axis=0)
classWeight = dict()

for i in range(0, len(classTotals)):
    classWeight[i] = classTotals.max() / classTotals[i]

(trainX, testX, trainY, testY) = train_test_split(data, labels, test_size=0.20, stratify=labels, random_state=42)

print('[INFO] compiling model...')
model = LeNet.build(width=28, height=28, depth=1, classes=2)
model.compile(loss=['binary_crossentropy'], optimizer='adam', metrics=['accuracy'])

print('[INFO] training network...')
H = model.fit(trainX, trainY, validation_data=(testX, testY), class_weight=classWeight, batch_size=64, epochs=15, verbose=1)

print('[INFO] evaluating network...')
predictions = model.predict(testX, batch_size=64)
print(classification_report(testY.argmax(axis=1), predictions.argmax(axis=1), target_names=le.classes_))

print('[INFO] serializing network')
model.save(args['model'])

plt.style.use('ggplot')
plt.figure()
plt.plot(np.arange(0, 15), H.history['loss'], label='train_loss')
plt.plot(np.arange(0, 15), H.history['val_loss'], label='val_loss')
plt.plot(np.arange(0, 15), H.history['accuracy'], label='accuracy')
plt.plot(np.arange(0, 15), H.history['val_accuracy'], label='val_accuracy')
plt.title('Training Loss and Accuracy')
plt.xlabel('Epoch #')
plt.ylabel('Loss/Accuracy')
plt.legend()
plt.show()
