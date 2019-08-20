#!/bin/bash

# Copyright 2012 Vassil Panayotov
# Apache 2.0

#이제 본격적으로 train과 test화자를 분류해서 mfcc를 뽑기위해 준비하는 과정이다. 



source ./path.sh

echo "=== Preparing train and test data ..."
#train과 test에 분리해서 저장하기위해 필요한 경로들을 변수로 선언
srcdir=data/local
lmdir=data/local/
tmpdir=data/local/lm_tmp
lexicon=data/local/dict/lexicon.txt
mkdir -p $tmpdir

#원래 가지고 있던 파일들을 train과 test폴더에 똑같이 만들어 준다.
for x in train test; do
  mkdir -p data/$x
  cp $srcdir/${x}_wav.scp data/$x/wav.scp || exit 1;
  cp $srcdir/${x}_trans.txt data/$x/text || exit 1;
  cp $srcdir/$x.spk2utt data/$x/spk2utt || exit 1;
  cp $srcdir/$x.utt2spk data/$x/utt2spk || exit 1;
  utils/filter_scp.pl data/$x/spk2utt $srcdir/spk2gender > data/$x/spk2gender || exit 1;
done


# Next, for each type of language model, create the corresponding FST
# and the corresponding lang_test_* directory.

#여기부터 설명 추가
echo "--- Preparing the grammar transducer (G.fst) for testing ..."

test=data/lang_test
mkdir -p $test
for f in phones.txt words.txt phones.txt L.fst L_disambig.fst phones; do
    cp -r data/lang/$f $test
done
cat $lmdir/lm.arpa | \
  arpa2fst --disambig-symbol=#0 \
           --read-symbol-table=$test/words.txt - $test/G.fst
fstisstochastic $test/G.fst
# The output is like:
# 9.14233e-05 -0.259833
# we do expect the first of these 2 numbers to be close to zero (the second is
# nonzero because the backoff weights make the states sum to >1).
# Because of the <s> fiasco for these particular LMs, the first number is not
# as close to zero as it could be.

# Everything below is only for diagnostic.
# Checking that G has no cycles with empty words on them (e.g. <s>, </s>);
# this might cause determinization failure of CLG.
# #0 is treated as an empty word.
mkdir -p $tmpdir/g
awk '{if(NF==1){ printf("0 0 %s %s\n", $1,$1); }} END{print "0 0 #0 #0"; print "0";}' \
  < "$lexicon"  >$tmpdir/g/select_empty.fst.txt
fstcompile --isymbols=$test/words.txt --osymbols=$test/words.txt \
  $tmpdir/g/select_empty.fst.txt | \
fstarcsort --sort_type=olabel | fstcompose - $test/G.fst > $tmpdir/g/empty_words.fst
fstinfo $tmpdir/g/empty_words.fst | grep cyclic | grep -w 'y' &&
  echo "Language model has cycles with empty words" && exit 1
rm -rf $tmpdir

echo "*** Succeeded in formatting data."
