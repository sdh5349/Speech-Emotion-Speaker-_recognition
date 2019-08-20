import tensorflow as tf
import pickle
import numpy as np
import matplotlib.pyplot as plt
import librosa
from keras.models import Sequential
from keras import layers, models
from keras.layers import Dense, Dropout, Flatten
from keras.layers.convolutional import Conv2D, MaxPooling2D
from keras.models import load_model, Model
import random


def shuffle_batch(X, y, batch_size):
    rnd_idx = np.random.permutation(len(X))
    n_batches = len(X) // batch_size
    for batch_idx in np.array_split(rnd_idx, n_batches):
        X_batch, y_batch = X[batch_idx], y[batch_idx]
    return X_batch, y_batch

'''
data=[]
with open('/data/untitled/emotiondata/x_train_ravdess', 'rb') as f:
  data = pickle.load(f)
x_train=data
data=[]

data=[]
with open('/data/untitled/emotiondata/y_train_ravdess', 'rb') as f:
  data = pickle.load(f)
y_train=data
data=[]

'''
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



#x_train=np.array(x_train)
#y_train=np.array(y_train)


a=[]
for i in range(0, len(x_train)):
    a.append(librosa.feature.delta(x_train[i]))
print(np.shape(a))

x_train_del=a


a=[]
for i in range(0, len(x_train)):
    a.append(librosa.feature.delta(x_train_del[i]))
print(np.shape(a))

x_train_del_del=a

a=[]
for i in range(0, len(x_train)):
    a=np.append(x_train,x_train_del,axis=2)

print("A")
print(np.shape(a))

x_train=a


a=[]
for i in range(0, len(x_train)):
    a=np.append(x_train,x_train_del_del,axis=2)

x_train=a

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

print(np.shape(y_train))
print(np.shape(y_test))


x_train, y_train = shuffle_batch(x_train, y_train, len(x_train))
x_test, y_test = shuffle_batch(x_test, y_test, len(x_test))


epochs=100
batch_size=54

model=Sequential()



model.add(layers.LSTM((100), return_sequences=True,input_shape=(398,117)))
model.add(layers.LSTM((70) ,return_sequences=True))
model.add(layers.LSTM((50)))
model.add(Dense(30, activation='elu')) #return_sequences=True))
model.add(Dense(7, activation='softmax'))
model.summary()

model.compile(loss='categorical_crossentropy', optimizer='adam', metrics=['accuracy'])
hist = model.fit(x_train, y_train, epochs=epochs, batch_size=batch_size, validation_data=(x_test, y_test))

performace_test = model.evaluate(x_test, y_test, batch_size=30)
print('Test Loss and Accuracy ->', performace_test)


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


#model.save('./emotion_LSTM.h5')
