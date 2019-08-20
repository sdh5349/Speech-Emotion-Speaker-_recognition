import tensorflow as tf
import numpy as np
import pickle
from keras.models import Sequential
from keras.layers import Dense, Dropout, Flatten
from keras.layers.convolutional import Conv2D, MaxPooling2D
from keras.models import load_model, Model
from keras.preprocessing import sequence
from keras.datasets import imdb
from keras import layers, models

def shuffle_batch(X, y, batch_size):
    rnd_idx = np.random.permutation(len(X))
    n_batches = len(X) // batch_size
    for batch_idx in np.array_split(rnd_idx, n_batches):
        X_batch, y_batch = X[batch_idx], y[batch_idx]
    return X_batch, y_batch


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

learning_rate = 0.001
total_epoch = 30
batch_size = 10

# RNN 은 순서가 있는 자료를 다루므로,|
# 한 번에 입력받는 갯수와, 총 몇 단계로 이루어져있는 데이터를 받을지를 설정해야합니다.

n_input = 39
n_step = 398
n_hidden = 7

n_class = 7
X = tf.placeholder(tf.float32, [None, n_step, n_input])
Y = tf.placeholder(tf.float32, [None, n_class])

W = tf.Variable(tf.random_normal([n_hidden, n_class]))
b = tf.Variable(tf.random_normal([n_class]))

#cell = tf.nn.rnn_cell.BasicRNNCell(n_hidden)
#cell = tf.nn.rnn_cell.BasicLSTMCell(n_hidden)

#cell1 = tf.nn.rnn_cell.BasicRNNCell(n_hidden)
#cell2 = tf.nn.rnn_cell.BasicRNNCell(n_hidden)
cell1 = tf.nn.rnn_cell.BasicLSTMCell(n_hidden)
cell2 = tf.nn.rnn_cell.BasicLSTMCell(n_hidden)
#cell3 = tf.nn.rnn_cell.BasicLSTMCell(n_hidden)
cell=tf.nn.rnn_cell.MultiRNNCell([cell1, cell2])
outputs, states = tf.nn.dynamic_rnn(cell, X, dtype=tf.float32)
outputs = tf.transpose(outputs, [1, 0, 2])
outputs = outputs[-1]
model = tf.matmul(outputs, W) + b
model1=tf.nn.softmax(model)
cost = tf.reduce_mean(tf.nn.softmax_cross_entropy_with_logits_v2(logits=model, labels=Y))
optimizer = tf.train.AdamOptimizer(learning_rate).minimize(cost)
sess = tf.Session()
sess.run(tf.global_variables_initializer())

total_batch = 30

for epoch in range(60):
    total_cost = 0

    for i in range(total_batch):
       # x_train , y_train = shuffle_batch(x_train, y_train, total_batch)
        _, cost_val = sess.run([optimizer, cost],
                               feed_dict={X: x_train, Y: y_train})
        total_cost += cost_val

    print('Epoch:', '%04d' % (epoch + 1),
          'Avg. cost =', '{:.3f}'.format(total_cost / total_batch))
    
print('최적화 완료!')

RNN1=(sess.run(model1, feed_dict={X: x_test, Y: y_test}))

#########
# 결과 확인
######
is_correct = tf.equal(tf.argmax(model, 1), tf.argmax(Y, 1))
accuracy = tf.reduce_mean(tf.cast(is_correct, tf.float32))


print('정확도:', sess.run(accuracy,
                       feed_dict={X: x_test, Y: y_test}))

#print(np.shape(x_train[0]))
#emotion=model.predict_classes(x_train[0])
#print(emotion)
#model.save('./dong.h5')

