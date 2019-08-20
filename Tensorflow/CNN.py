import sys
import tensorflow as tf
import keras
from keras.models import Sequential
from keras.layers import Dense, Dropout, Flatten
from keras.layers.convolutional import Conv2D, MaxPooling2D
import numpy as np


img_rows = 28
img_cols = 28

(x_train, y_train), (x_test, y_test) = keras.datasets.mnist.load_data()

input_shape = (img_rows, img_cols, 1)
x_train = x_train.reshape(x_train.shape[0], img_rows, img_cols, 1)
x_test = x_test.reshape(x_test.shape[0], img_rows, img_cols, 1)

x_train = x_train.astype('float32') / 255.
x_test = x_test.astype('float32') / 255.



batch_size = 128
num_classes = 10
epochs = 12

y_train = keras.utils.to_categorical(y_train, num_classes)
y_test = keras.utils.to_categorical(y_test, num_classes)


class CNN_seq(tf.keras.models.Sequential):
   def __init__(self, input_shape, num_classes):
        super().__init__()
        self.add(tf.keras.layers.Conv2D(8, kernel_size=(5, 5), strides=(1, 1), padding='same',activation='relu', input_shape=input_shape))
        self.add(tf.keras.layers.MaxPooling2D(pool_size=(2, 2), strides=(2, 2)))
        self.add(tf.keras.layers.Conv2D(16, (2, 2), activation='relu', padding='same'))
        self.add(tf.keras.layers.MaxPooling2D(pool_size=(2, 2)))
        self.add(tf.keras.layers.Dropout(0.25))
        self.add(tf.keras.layers.Flatten())
        self.add(tf.keras.layers.Dense(1000, activation='relu'))
        self.add(tf.keras.layers.Dropout(0.5))
        self.add(tf.keras.layers.Dense(num_classes, activation='softmax'))
        self.summary()
        self.compile(loss='categorical_crossentropy', optimizer='adam', metrics=['accuracy'])
        
        
        
model=CNN_seq(input_shape,num_classes)

hist = model.fit(x_train, y_train, batch_size=100, epochs=epochs, verbose=1, validation_data=(x_test, y_test))


import matplotlib.pyplot as plt

fig, loss_ax = plt.subplots()

acc_ax = loss_ax.twinx()


acc_ax.plot(hist.history['acc'], 'b', label='train acc')
acc_ax.plot(hist.history['val_acc'], 'g', label='val acc')
loss_ax.plot(hist.history['loss'], 'y', label='train loss')
loss_ax.plot(hist.history['val_loss'], 'r', label='val loss')




acc_ax.set_ylabel('accuray')
loss_ax.set_xlabel('epoch')
loss_ax.set_ylabel('loss')




acc_ax.legend(loc='lower left')
loss_ax.legend(loc='upper left')





plt.show()
