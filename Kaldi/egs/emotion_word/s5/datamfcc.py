import os
import sys
import librosa
from typing import Tuple
import pickle
import numpy as np
import scipy.io.wavfile as wav
from speechpy.feature import mfcc


def get_feature_vector_from_mfcc(file_path: str, flatten: bool,
                                 mfcc_len: int = 39) -> np.ndarray:
    fs=48000
    #fs, signal = librosa.load(file_path)
    #print(fs)
    #print(np.shape(signal))
    signal=down_sample(file_path, fs, 8000)
    fs=8000
    s_len = len(signal)
    # pad the signals to have same size if lesser than required
    # else slice them
    if s_len < mean_signal_length:
        pad_len = mean_signal_length - s_len
        pad_rem = pad_len % 2
        pad_len //= 2
        signal = np.pad(signal, (pad_len, pad_len + pad_rem),
                        'constant', constant_values=0)
    else:
        pad_len = s_len - mean_signal_length
        pad_len //= 2
        signal = signal[pad_len:pad_len + mean_signal_length]
    mel_coefficients = mfcc(signal, fs, num_cepstral=mfcc_len)
    #if flatten:
    #    #Flatten the data
    #    mel_coefficients = np.ravel(mel_coefficients)
    return mel_coefficients


def down_sample(input_wav, origin_sr, resample_sr):

  y, sr = librosa.load(input_wav, sr=origin_sr)
  resample = librosa.resample(y, sr, resample_sr)
  print("original wav sr: {}, original wav shape: {}, resample wav sr: {}, resmaple shape: {}".format(origin_sr, y.shape, resample_sr, resample.shape))
  return resample

to_flatten = True
mean_signal_length = 32000


### name path ###
datapath="/data/untitled/edata/"
full_fname_train=[]
for root, dirs, files in os.walk(datapath):
  for fname in files:
    full_fname_train.append(os.path.join(root, fname))

num_train= len(full_fname_train)

num=21 #정답
print(full_fname_train[0][num:]) #정답번호
print(full_fname_train[3][num:]) #정답번호


y_train=[]
for i in range(0, (num_train)):
  k=int(full_fname_train[i][num])
  y=[0, 0, 0, 0, 0, 0, 0, 0]
  y[k]=1
  y_train.append(y)

y_train=np.array(y_train)
print(np.shape(y_train))
### resample ###

#origin_sr, y = wav.read(full_fname_train[0])
#print(origin_sr)


#resample_sr=8000
#resample=[]
#for i in range(0,2 ):#num_train):
#    resample.append(down_sample(full_fname_train[i], origin_sr, resample_sr))




x_train=[]
for i in range(0, num_train):
    x_train.append(get_feature_vector_from_mfcc(full_fname_train[i], flatten=to_flatten))


print(np.shape(x_train)) 
print(np.shape(y_train)) 

with open('/data/untitled/emotiondata/x_train_ravdess', 'wb') as f:
  pickle.dump(x_train, f)

with open('/data/untitled/emotiondata/y_train_ravdess', 'wb') as f:
  pickle.dump(y_train, f)



