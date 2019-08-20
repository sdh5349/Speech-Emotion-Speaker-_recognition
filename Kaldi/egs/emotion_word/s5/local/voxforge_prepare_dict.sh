#!/bin/bash

# Copyright 2012 Vassil Panayotov
# Apache 2.0

. ./path.sh || exit 1

#발음사전을 만들기 위한 스크립트이다.

#저장을 위해 변수를 지정 
locdata=data/local
locdict=$locdata/dict

echo "=== Preparing the dictionary ..."


#발음사전을 cmudict를 받는다. -> 발음사전을 만들기 위한 것
if [ ! -f $locdict/cmudict/cmudict.0.7a ]; then
  echo "--- Downloading CMU dictionary ..."
  mkdir -p $locdict
  svn co http://svn.code.sf.net/p/cmusphinx/code/trunk/cmudict \
    $locdict/cmudict || exit 1;
fi

#받은 cmudict을 이용해 cmudict-plain.txt를 만든다. -> 영어 발음사전 
echo "--- Striping stress and pronunciation variant markers from cmudict ..."
perl $locdict/cmudict/scripts/make_baseform.pl \
  $locdict/cmudict/cmudict.0.7a /dev/stdout |\
  sed -e 's:^\([^\s(]\+\)([0-9]\+)\(\s\+\)\(.*\):\1\2\3:' > $locdict/cmudict-plain.txt

#vocab-oov.txt(문법에 상관쓰지 않고 모든말이 담겨있다.)와 lexicon-iv.txt(vocab-oov.txt이외에 말을 담는다) 파일을 만든다.
echo "--- Searching for OOV words ..."
awk 'NR==FNR{words[$1]; next;} !($1 in words)' \
  $locdict/cmudict-plain.txt $locdata/vocab-full.txt |\
  egrep -v '<.?s>' > $locdict/vocab-oov.txt

awk 'NR==FNR{words[$1]; next;} ($1 in words)' \
  $locdata/vocab-full.txt $locdict/cmudict-plain.txt |\
  egrep -v '<.?s>' > $locdict/lexicon-iv.txt

#다음 파일들의 갯수를 보여준다.
wc -l $locdict/vocab-oov.txt
wc -l $locdict/lexicon-iv.txt

#G2P model을 다운로드 한다. G2P모델은 Grapheme to Phoneme 의 약자로 문자소로 표현된 단어나 문장을 음소로 변환하는 작업을 의미
#실제 발음 될 음소로 변환하는 작업이 필요하기 때문에 생성한다.     실제 소리로 문장을 변환할때 각 문자소를 바로 소리로 변환하지 않기 때문
if [ ! -f conf/g2p_model ]; then
  echo "--- Downloading a pre-trained Sequitur G2P model ..."
  wget http://sourceforge.net/projects/kaldi/files/sequitur-model4 -O conf/g2p_model
  if [ ! -f conf/g2p_model ]; then
    echo "Failed to download the g2p model!"
    exit 1
  fi
fi
# Mac OS에서 필요 상관 안써도됨
if [[ "$(uname)" == "Darwin" ]]; then
  command -v greadlink >/dev/null 2>&1 || \
    { echo "Mac OS X detected and 'greadlink' not found - please install using macports or homebrew"; exit 1; }
  alias readlink=greadlink
fi

#이제 sequitur이라는 툴이 필요하다 아래의 변수들은 sequitur의 사용을 위해 변수를 선언 해준것 export는 연결된 전체스크립트에 변수 지정
sequitur=$KALDI_ROOT/tools/sequitur
export PATH=$PATH:$sequitur/bin
export PYTHONPATH=$PYTHONPATH:`utils/make_absolute.sh $sequitur/lib/python*/site-packages`

#sequitrur이 있는지 없는지 확인 
if ! g2p=`which g2p.py` ; then
  echo "The Sequitur was not found !"
  echo "Go to $KALDI_ROOT/tools and execute extras/install_sequitur.sh"
  exit 1
fi
#우리가 g2p모델을 이용해  이전에 만들었던 vocab-oov파일을 lexicon-oov로 만든다. g2p를 적용
echo "--- Preparing pronunciations for OOV words ..."
g2p.py --model=conf/g2p_model --apply $locdict/vocab-oov.txt > $locdict/lexicon-oov.txt

cat $locdict/lexicon-oov.txt $locdict/lexicon-iv.txt |\
  sort > $locdict/lexicon.txt
rm $locdict/lexiconp.txt 2>/dev/null || true
#최종적으로 lexicon-oov파일과 이전에 만든 lexicon-iv를 이용해 lexicon.txt파일을 만든다.


#아래는 silence를 목록에 추가한다.  그리고 silence와 nonsilence를 분리
echo "--- Prepare phone lists ..."
echo SIL > $locdict/silence_phones.txt
echo SIL > $locdict/optional_silence.txt
grep -v -w sil $locdict/lexicon.txt | \
  awk '{for(n=2;n<=NF;n++) { p[$n]=1; }} END{for(x in p) {print x}}' |\
  sort > $locdict/nonsilence_phones.txt

echo "--- Adding SIL to the lexicon ..."
echo -e "!SIL\tSIL" >> $locdict/lexicon.txt

# Some downstream scripts expect this file exists, even if empty
touch $locdict/extra_questions.txt

echo "*** Dictionary preparation finished!"
