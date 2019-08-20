#!/bin/bash

# Copyright 2012 Vassil Panayotov
# Apache 2.0

# Selects parts of VoxForge corpus based on certain criteria
# and makes symbolic links to the respective recordings 

# regex to select speakers based on pronunciation dialect
dialect='(American)|(British)'   #무슨 언어를 인식할지 

# e.g. accept a "dialect" parameter
. utils/parse_options.sh   #parse_ption.sh 파일을 읽어온다. 

echo "=== Starting VoxForge subset selection(accent: $dialect) ..."

if [ $# -ne 2 ]; then    #만약 받는 인수가 2개가 아니면 
  echo "Usage: $0 [--dialect <regex>] <src-dir> <dst-dir>";
  exit 1;
fi

SRCDIR=$1     #첫번째 인수(출발 소스)를 SRCDIR변수로 저장-->$DATAROOT
DSTDIR=$2     #두번째 인수(목적지 저장할 공간)를 DSTDIR변수로 저장 -->selected

rm -rf ${DSTDIR} 1>/dev/null 2>&1   # DSTDIR을 지운다 그리고 오류가 나면 오류가 난 문구를 저장
mkdir -p ${DSTDIR}                  # DSTDIR폴더를 만든다. -p은 그 사이의 폴더가 없을 때 만들어준다. 

find $SRCDIR -iwholename '*etc/readme*' \
 -exec egrep -iHl 'pronunciation dialect.*'${dialect} {} \; |\
while read f; do      #$DATAROOT 에서 찾은 etc/readme중에서 우리가 인식하기로 했던 언어들에 해당 하는파일을 찾느다.
  d=`dirname $f`;  #dirname은 입력된 경로로부터 폴더를 찾는것 -> 위에서 해당하는 파일들의 폴더를 의미  
  d=`dirname $d`; 
  ln -s $d ${DSTDIR}; #찾은(인식할 파일이있는) 폴더를 selected 폴더에 소프트링크로 넣는다. 
done

echo "*** VoxForge subset selection finished!"
