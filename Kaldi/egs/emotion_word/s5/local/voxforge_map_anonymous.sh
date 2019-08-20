#!/bin/bash

# Copyright 2012 Vassil Panayotov
# Apache 2.0

# Map anonymous users to unique IDs

echo "=== Starting to map anonymous users to unique IDs ..."

if [ $# -ne 1 ]; then             #인수가 1개가 아니면 다음 문구를 출력하고 종료 
  echo "Usage: $0 <data-dir>"
  exit 1
fi

data=$1    #첫번째 인수(data) 를 $data의값으로 넣어준다. 
data_local=data/local #data_local은 data/local 

if [ ! -d $data ]; then  #$data가 디렉토리가 아니면 다음 문 구를 출력하고 종료
  echo "\"$DATA\" is not a directory!"
  exit 1
fi

mkdir -p $data_local #data/local 디렉토리를 만든다 

echo "--- Mapping the \"anonymous\" speakers to unique IDs ..." # 다음 문구를 출력 
#ls -d 는 지정 디렉토리에서 파일을 제외한 디렉토리 목록을 출력 
ls -d $data/anonymous-*-* |\
 awk '
 BEGIN {i=0}
 { anon_users[++i] = $0; }
 END { for (j in anon_users) {printf("anonymous%04d %s\n", j, anon_users[j]);}}' |\
 sort -k1 > $data_local/anon.map
#awk는 데이터를 조작하고 리포트를 생성하기 위해 사용하는 언어


while read l; do
  user=$(echo $l | cut -f1 -d' ')
  echo "$l" | cut -f2- -d' ' | while read -r ad; do
    newdir=`echo "$ad" | sed -e 's:anonymous\(-.*-.*\):'$user'\1:'`
    mv $ad $newdir
  done
done < "${data_local}/anon.map"

echo "*** Finished mapping anonymous users!"
