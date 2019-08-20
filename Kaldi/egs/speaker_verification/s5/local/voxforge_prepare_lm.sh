#!/bin/bash

# Copyright 2012 Vassil Panayotov
# Apache 2.0

. ./path.sh || exit 1

echo "=== Building a language model ..."

#language model을 만들기 위해 준비하는 단계 언어모델은 주로 n-gram 모델 많이사용 단어의 활용이 바로 전 n-1개의 단어의 의존

#저장 위치를 위해 폴더 경로를 변수로 지정
locdata=data/local
loctmp=$locdata/tmp

echo "--- Preparing a corpus from test and train transcripts ..."

# Language model order
order=3
#n-gram에서 n에 해당



. utils/parse_options.sh
#utt 파일을 만들때 무슨말을 했는지를 원하기 때문에 자른다.

# Prepare a LM training corpus from the transcripts _not_ in the test set
cut -f2- -d' ' < $locdata/test_trans.txt |\
  sed -e 's:[ ]\+: :g' | sort -u > $loctmp/test_utt.txt


#train도 마찬가지 
# We are not removing the test utterances in the current version of the recipe
# because this messes up with some of the later stages - e.g. too many OOV
# words in tri2b_mmi
cut -f2- -d' ' < $locdata/train_trans.txt |\
   sed -e 's:[ ]\+: :g' |\
   sort -u > $loctmp/corpus.txt

#SRILM을 다운 SRILM은 음성인식을 위해 언어 모델을 작성하고 적용하기 위한 툴킷이다.
#if -z는 문자열 사이즈가 0인지 체크 0이면 참이다.
loc=`which ngram-count`;
if [ -z $loc ]; then
  if uname -a | grep 64 >/dev/null; then # some kind of 64 bit...
    sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64 
  else
    sdir=$KALDI_ROOT/tools/srilm/bin/i686
  fi
  if [ -f $sdir/ngram-count ]; then
    echo Using SRILM tools from $sdir
    export PATH=$PATH:$sdir
  else
    echo You appear to not have SRILM tools installed, either on your path,
    echo or installed in $sdir.  See tools/install_srilm.sh for installation
    echo instructions.
    exit 1
  fi
fi

#다운받은 SRILM을 이용하여 vocab-full(모든말) corpus.txt(말)를 이용해 lm.arpa(언어 모델)파일을 마든다.
ngram-count -order $order -write-vocab $locdata/vocab-full.txt -wbdiscount \
  -text $loctmp/corpus.txt -lm $locdata/lm.arpa

echo "*** Finished building the LM model!"
