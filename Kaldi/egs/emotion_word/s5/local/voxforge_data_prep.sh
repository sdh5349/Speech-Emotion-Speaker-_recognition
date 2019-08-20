#!/bin/bash

# Copyright 2012  Vassil Panayotov
#           2014  Johns Hopkins University (author: Daniel Povey)
# Apache 2.0

# Makes train/test splits

. ./path.sh

echo "=== Starting initial VoxForge data preparation ..."

echo "--- Making test/train data split ..."

# The number of speakers in the test set
nspk_test=30

. utils/parse_options.sh

if [ $# != 1 ]; then        #인수가 하나가 아니면 다음 문장을 출력하고 종료 
  echo "Usage: $0 <data-directory>";
  exit 1;
fi

command -v flac >/dev/null 2>&1 ||\
 { echo "FLAC decompressor needed but not found"'!' ; exit 1; }
#flac이란 모듈이 필요 없으면 종료 flac은 wav를 다룰때 필요한 모듈 

DATA=$1   #천번째인수를 DATA란 이름의 변수에 넣어준다 첫번째인수는 데이터의 위치 

locdata=data/local   
loctmp=$locdata/tmp  #loctmp=data/local/tmp
rm -rf $loctmp >/dev/null 2>&1   #그전에 있을수도 있는 loctmp 디렉토리를 삭제 
mkdir -p $locdata   #data/local 폴더를 만들고
mkdir -p $loctmp    #data/local/tmp 폴더도 만든다.
# The "sed" expression below is quite messy because some of the directrory
# names don't follow the "speaker-YYYYMMDD-<random_3letter_suffix>" convention.
# The ";tx;d;:x" part of the expression is to filter out the directories,
# not matched by the expression
find $DATA/ -mindepth 1 -maxdepth 1 |\
 perl -ane ' s:.*/((.+)\-[0-9]{8,10}[a-z]*([_\-].*)?):$2: && print; ' | \
  sort -u > $loctmp/speakers_all.txt
#mindepth와 maxdepth는 파일의 깊이를 조절 1이면 자기 자신의 디렉토리를 의미 그리고 mini~부터  max ~ 까지
#즉 여기서는 data 자기자신의 폴더를 의미 data폴더의 화자들의 이름(폴더이름)을 이용해 speakers_all.txt를만듬 


nspk_all=$(wc -l <$loctmp/speakers_all.txt)   #speaker_all.txt에 있는 화자들이 몇명인지 
if [ "$nspk_test" -ge "$nspk_all" ]; then   # 테스트수가 모든 화자수보다 많으면 다음문구를 출력하고 종료1
  echo "${nspk_test} test speakers requested, but there are only ${nspk_all} speakers in total!"
  exit 1;
fi

utils/shuffle_list.pl <$loctmp/speakers_all.txt | head -n $nspk_test | sort -u >$loctmp/speakers_test.txt
#모든화자의 목록을 섞은후 그중에 test화자 목록을 뽑아낸다.



awk 'NR==FNR{spk[$0]; next} !($0 in spk)' \
  $loctmp/speakers_test.txt $loctmp/speakers_all.txt |\
  sort -u > $loctmp/speakers_train.txt
#모든 화자목록과 테스트 화자 목록중 겹치지 않는것을 훈련화자 목록으로 만든다.

wc -l $loctmp/speakers_all.txt 
wc -l $loctmp/speakers_{train,test}.txt
#all, train, test 화자들의 수를 출력



# expand speaker names to their respective directories
for d in $(find ${DATA}/ -mindepth 1 -maxdepth 1 -type l -or -type d); do
  basename $d                           #$DATA디렉토리에서 링크파일(-l)이나 디렉토리(-d)를 찾아라 
done | awk 'BEGIN {FS="-"} NR==FNR{arr[$1]; next;} ($1 in arr)' \
  $loctmp/speakers_test.txt - | sort > $loctmp/dir_test.txt
#speakers_test.txt 파일의 필드 구분자를 '-'로 한다 NR은 총 레코드수 FNR 은 현재파일을 레코드 수  

if [ ! -s $loctmp/dir_test.txt ]; then   #dir_test.txt가 존재지 않으면 다음 문장출력하고 종료 
  echo "$0: file $loctmp/dir_test.txt is empty"
  exit 1;
fi

for d in $(find ${DATA}/ -mindepth 1 -maxdepth 1 -type l -or -type d); do
  basename $d;   #$DATA디렉토리에서 링크파일(-l)이나 디렉토리(-d)를 찾아라 
done | awk 'BEGIN {FS="-"} NR==FNR{arr[$1]; next;} ($1 in arr)' \
  $loctmp/speakers_train.txt - | sort > $loctmp/dir_train.txt

if [ ! -s $loctmp/dir_test.txt ]; then
  echo "$0: file $loctmp/dir_train.txt is empty"
  exit 1;
fi


logdir=exp/data_prep
mkdir -p $logdir  #exp/data_prep 디렉토리를 만든다 
echo -n > $logdir/make_trans.log 
rm ${locdata}/spk2gender 2>/dev/null #data/local/spk2gender를 삭제 그리고 오류가 있으면 저장 
for s in test train; do   #test와 train 순서로 반복 
  echo "--- Preparing ${s}_wav.scp, ${s}_trans.txt and ${s}.utt2spk ..." 

  for d in $(cat $loctmp/dir_${s}.txt); do  #d는 data/local/tmp/dir_test.txt와 dir_train.txt의 목록
    spkname=`echo $d | cut -f1 -d'-'`;      #spkname은 목록에서 첫번째 단어 
    spksfx=`echo $d | cut -f2- -d'-'`; # | sed -e 's:_:\-:g'`;  spksfx는 두번째 단어 
    idpfx="${spkname}-${spksfx}";  #idpfx는 spkname-spksfx 
    dir=${DATA}/$d   #dir은 data/test와 train

    rdm=`find $dir/etc/ -iname 'readme'`   #rdm은 readme 파일 
    if [ -z $rdm ]; then  #readme파일이 없으면 다음문구 출력하고 종료 
      echo "No README file for $d - skipping this directory ..."
      continue
    fi
    spkgender=$(perl -ane ' s/.*gender\:\W*(.).*/lc($1)/ei && print; ' <$rdm)
    if [ "$spkgender" != "f" -a "$spkgender" != "m" ]; then #spkgender가 f 와 m이 아니면 다음문구를 출력하고 m으로 통일
      echo "Illegal or empty gender ($spkgender) for \"$d\" - assuming m(ale) ..."
      spkgender="m"
    fi
    echo "$spkname $spkgender" >> $locdata/spk2gender.tmp   #spkgender의 정보를 data/local/tmp/spk2gender.tmp로저장
    
#PROMTS파일이 없으면 다음문구를 출력하고 그 log를 make_trains.log에 저장한후 계속 한다. 
    if [ ! -f ${dir}/etc/PROMPTS ]; then  
      echo "No etc/PROMPTS file exists in $dir - skipping the dir ..." \
        >> $logdir/make_trans.log
      continue
    fi
#음성파일이 wav인지 flac인지를판단    
    if [ -d ${dir}/wav ]; then
      wavtype=wav
    elif [ -d ${dir}/flac ]; then
      wavtype=flac
    else
      echo "No 'wav' or 'flac' dir in $dir - skipping ..."
      continue
    fi
    
#all_wavs와 all_utt2spk_entries list선언 
    all_wavs=()
    all_utt2spk_entries=()
# 아래의 for문은 음성파일 즉 wav파일을 받아오기 위한것 
# 그리고 만약에 wav파일이 없어나 wav파일의 형식이 정해준 형식과 맞지 않는다면 실행이 안된다.
    for w in ${dir}/${wavtype}/*${wavtype}; do
      bw=`basename $w`
      wavname=${bw%.$wavtype}
      all_wavs+=("$wavname")
      id="${idpfx}-${wavname}"
      if [ ! -s $w ]; then
        echo "$w is zero-size - skipping ..." 1>&2
        continue
      fi
      if [ $wavtype == "wav" ]; then
        echo "$id $w"
      else
        echo "$id flac -c -d --silent $w |"
      fi
      all_utt2spk_entries+=("$id $spkname")
    done >> ${loctmp}/${s}_wav.scp.unsorted

    for a in "${all_utt2spk_entries[@]}"; do echo $a; done >> $loctmp/${s}.utt2spk.unsorted


    if [ ! -f ${loctmp}/${s}_wav.scp.unsorted ]; then
      echo "$0: processed no data: error: pattern ${dir}/${wavtype}/*${wavtype} might match nothing"
      exit 1;
    fi   
    
    local/make_trans.py $dir/etc/PROMPTS ${idpfx} "${all_wavs[@]}" \
      2>>${logdir}/make_trans.log >> ${loctmp}/${s}_trans.txt.unsorted
  done

#양식에 맞지 않는 wav파일을 걸러낸후 wav.scp와 utt2spk 그리고 trains.txt 파일을 만드는데 각각 파일이름과 파일위치을 연결,  파일이름과 화자를 연결 말한말을 이미 
 # filter out the audio for which there is no proper transcript
  awk 'NR==FNR{trans[$1]; next} ($1 in trans)' FS=" " \
    ${loctmp}/${s}_trans.txt.unsorted ${loctmp}/${s}_wav.scp.unsorted |\
   sort -k1 > ${locdata}/${s}_wav.scp
  
  awk 'NR==FNR{trans[$1]; next} ($1 in trans)' FS=" " \
    ${loctmp}/${s}_trans.txt.unsorted $loctmp/${s}.utt2spk.unsorted |\
   sort -k1 > ${locdata}/${s}.utt2spk
  
  sort -k1 < ${loctmp}/${s}_trans.txt.unsorted > ${locdata}/${s}_trans.txt

  echo "--- Preparing ${s}.spk2utt ..."
  cat $locdata/${s}_trans.txt |\
  cut -f1 -d' ' |\
  awk 'BEGIN {FS="-"}
        {names[$1]=names[$1] " " $0;}
        END {for (k in names) {print k, names[k];}}' | sort -k1 > $locdata/${s}.spk2utt
done;

#아래의 if문은 trans파일을 말들때 오류가 발생했다면 오류를 설명해준다.  오류는 make_train.log에 저장
trans_err=$(wc -l <${logdir}/make_trans.log)
if [ "${trans_err}" -ge 1 ]; then
  echo -n "$trans_err errors detected in the transcripts."
  echo " Check ${logdir}/make_trans.log for details!" 
fi

#음성파일에 해당하는 화자들의 성별정보가 담겨있는 파일을 만든다. 
awk '{spk[$1]=$2;} END{for (s in spk) print s " " spk[s]}' \
  $locdata/spk2gender.tmp | sort -k1 > $locdata/spk2gender

echo "*** Initial VoxForge data preparation finished!"
