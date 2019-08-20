import tensorflow as tf
import numpy as np
import pickle
from keras.models import Sequential
from keras.layers import Dense, Dropout, Flatten
from keras.layers.convolutional import Conv2D, MaxPooling2D
from keras.models import load_model, Model


data=[]
with open('/data/untitled/emotiondata/x_train', 'rb') as f:
  data = pickle.load(f)
x_train=data
data=[]

data=[]
with open('/data/untitled/emotiondata/y_train', 'rb') as f:
  data = pickle.load(f)
y_train=data
data=[]

x_train=np.array(x_train)

y_train=np.array(y_train)



x_trains=[]
y_trains=[]
x_test=[]
y_test=[]
for i in range(0, len(x_train)):
    if i%10==0:
        x_test.append(x_train[i])
        y_test.append(y_train[i])

    else:
        x_trains.append(x_train[i])
        y_trains.append(y_train[i])

x_train=np.array(x_trains)
y_train=np.array(y_trains)

x_test=np.array(x_test)
y_test=np.array(y_test)

print(np.shape(x_train))
print(np.shape(x_test))



img_rows = 1
img_cols = 15522
input_shape = (img_rows, img_cols, 1)


x_train = x_train.reshape(x_train.shape[0], img_rows, img_cols,1)
x_test = x_test.reshape(x_test.shape[0], img_rows, img_cols,1)

print(np.shape(x_train))

batch_size = 10
num_classes = 7
epochs = 100
model = Sequential()
model.add(Conv2D(32, kernel_size=(1, 20), strides=(1, 10), padding='same',activation='relu', input_shape=input_shape))
model.add(MaxPooling2D(pool_size=(1, 10), strides=(1, 10)))
model.add(Dropout(0.25))
model.add(Conv2D(16, (1, 30), activation='relu', padding='same'))
model.add(MaxPooling2D(pool_size=(1, 2)))
model.add(Conv2D(8, (1, 30), activation='relu', padding='same'))
model.add(MaxPooling2D(pool_size=(1, 2)))
model.add(Dropout(0.25))
model.add(Flatten())
model.add(Dense(300, activation='relu'))
model.add(Dropout(0.5))
model.add(Dense(num_classes, activation='softmax'))
model.summary()
model.compile(loss='categorical_crossentropy', optimizer='adam', metrics=['accuracy'])
model.fit(x_train, y_train, batch_size=30, epochs=epochs, verbose=1, validation_data=(x_test, y_test))
print(np.shape(x_train[0]))
emotion=model.predict_classes(x_train[0])
print(emotion)
model.save('./dong.h5')

