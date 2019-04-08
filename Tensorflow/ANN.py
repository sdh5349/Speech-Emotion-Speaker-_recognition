import tensorflow as tf
import numpy as np
from keras import datasets  # mnist
from keras.utils import np_utils  # to_categorical

### 모델 구축 ###
class ANN_seq_class(tf.keras.models.Sequential):
    def __init__(self, Nin, Nh1, Nh2, Nout):
        super().__init__()
        self.add(tf.keras.layers.Dense(Nh1, activation='relu', input_shape=(Nin,)))
        self.add(tf.keras.layers.Dense(Nh2, activation='relu', input_shape=(Nin,)))
        self.add(tf.keras.layers.Dense(Nout, activation='softmax'))
        self.compile(loss='categorical_crossentropy', optimizer='adam', metrics=['accuracy'])

### 데이터 생성 ###
def Data_func():
    (X_train, y_train), (X_test, y_test) = datasets.mnist.load_data()

    Y_train = np_utils.to_categorical(y_train)
    Y_test = np_utils.to_categorical(y_test)

    L, W, H = X_train.shape
    X_train = X_train.reshape(-1, W * H)
    X_test = X_test.reshape(-1, W * H)

    X_train = X_train / 255.0
    X_test = X_test / 255.0

    return (X_train, Y_train), (X_test, Y_test)
    
(X_train, Y_train), (X_tests, Y_tests)=Data_func()

model=ANN_seq_class(784,200,100,10)
hist=model.fit(X_train, Y_train, validation_data=(X_tests, Y_tests), epochs=10, batch_size=1000, verbose=1)

print(hist.history['acc'])
print('\nAccuracy: {:.4f}'.format(model.evaluate(X_tests, Y_tests)[1]))


### 그래프 ###
import matplotlib.pyplot as plt

fig, loss_ax = plt.subplots()

acc_ax = loss_ax.twinx()


acc_ax.plot(hist.history['acc'], 'b', label='train acc')
acc_ax.plot(hist.history['val_acc'], 'g', label='val acc')

acc_ax.set_ylabel('accuray')
acc_ax.legend(loc='lower left')


plt.show()
