#!/bin/bash

# Copyright 2012 Vassil Panayotov
# Apache 2.0

# NOTE: You will want to download the data set first, before executing this script.
#       This can be done for example by:
#       1. Setting the variable DATA_ROOT in path.sh to point to a
#          directory with enough free space (at least 20-25GB
#          currently (Feb 2014))
#       2. Running "getdata.sh"

# The second part of this script comes mostly from egs/rm/s5/run.sh
# with some parameters changed

. ./path.sh || exit 1

#tool이나 src 그리고 데이터의 경로등 저장해논 스크립트 불러옴 
#kaldi를 돌리기위해 필요한 스크립트나 디렉토리 경로들 다있다고 보면된다.


# If you have cluster of machines running GridEngine you may want to
# change the train and decode commands in the file below
. ./cmd.sh || exit 1
#---------- 설명 -------------
#cmd는 훈련과 디코딩을 위한 병렬화를 지정가능 
#run.pl, queue.pl 그리고 slurm.pl 세 가지 옵션이 있다.
#run.pl -> 로컬 컴퓨터(ex: 개인컴퓨터)에서 실행가능
#queue.pl -> Sun Grid Engine을 사용하여 시스템에 작업을 할당가능
#slurm.pl -> SLURM이라는 Grid Engine 소프트웨어를 사용하여 시스템에 작업을 할당가능


# The number of parallel jobs to be started for some parts of the recipe
# Make sure you have enough resources(CPUs and RAM) to accomodate this number of jobs
njobs=8  
#---------- 설명 -------------
#병렬작업수 설정 컴퓨팅파워에 맞춰서 정해줘야한다.


# This recipe can select subsets of VoxForge's data based on the "Pronunciation dialect"
# field in VF's etc/README files. To select all dialects, set this to "English"
dialects="((base)|(noise)|(ward)|(etc)|(korean))"
#---------- 설명 -------------
#자신이 가지고 있는 음성 데이터의 디렉토리에는 etc/README 파일이 있는데 이 파일은 음성 데이터에 대한 설명이 적혀있다.
#README 파일에 적혀 있는 설명중 어떤 언어로 되어 있는지를 확인한 후 입력 


# The number of randomly selected speakers to be put in the test set
nspk_test=50
#---------- 설명 -------------
#test 화자의 숫자 설정 가지고 있는 음성데이터에 맞춰서 설정하면된다.


# Test-time language model order
lm_order=2
#---------- 설명 -------------
#language model의 order를 정함



# Word position dependent phones?
pos_dep_phones=true
#---------- 설명 -------------
#phone이 단어의 위치에 영향을 받는지



# The directory below will be used to link to a subset of the user directories
# based on various criteria(currently just speaker's accent)
selected=${DATA_ROOT}/selected
#---------- 설명 -------------
#selected라는 변수를 설정하는데 여기서 ${DATA_ROOT}는 가지고 있는 음성데이터의 위치
#나중에 ${DATA_ROOT}/selected 경로에 사용할 음성데이터의 링크 만들어진다. 



# The user of this script could change some of the above parameters. Example:
# /bin/bash run.sh --pos-dep-phones false
. utils/parse_options.sh || exit 1
#사용할 파라미터를 설정하는 스크립트 


[[ $# -ge 1 ]] && { echo "Unexpected arguments"; exit 1; }
# $# --> 받는 arguement   ge --> >=  


# Select a subset of the data to use
# WARNING: the destination directory will be deleted if it already exists!




local/voxforge_select.sh --dialect $dialects \
  ${DATA_ROOT}  ${selected} || exit 1
#---------- 설명 -------------
#가지고 있는 전체 데이터중 사용할 데이터를 선택하는 스크립트
#필요한 argument는 3가지  
#$dialects --> 위에서 설정한 사용할 음성파일의 특징 ex) korean, base 등등
#${DATA_ROOT} --> 음성 데이터의 디렉토리 경로 
#${selected} --> 전체 음성 데이터에서 원하는 데이터를 가져올때 저장할 디렉토리 경로 

# ${DATA_ROOT}(전체데이터 디렉토리경로)  에서 $dialects(원하는 언어(조건))에 해당하는 데이터를
# ${selected}(선택한 데이터 저장할 디렉토리 경로)에 저장한다.


# Mapping the anonymous speakers to unique IDs
local/voxforge_map_anonymous.sh ${selected} || exit 1

# Initial normalization of the data
local/voxforge_data_prep.sh --nspk_test ${nspk_test} ${selected} || exit 1

# Prepare ARPA LM and vocabulary using SRILM
local/voxforge_prepare_lm.sh --order ${lm_order} || exit 1

# Prepare the lexicon and various phone lists
# Pronunciations for OOV words are obtained using a pre-trained Sequitur model
local/voxforge_prepare_dict.sh || exit 1


# Prepare data/lang and data/local/lang directories
utils/prepare_lang.sh --position-dependent-phones $pos_dep_phones \
  data/local/dict '!SIL' data/local/lang data/lang || exit 1


# Prepare G.fst and data/{train,test} directories
local/voxforge_format_data.sh || exit 1

# Now make MFCC features.
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfccdir=${DATA_ROOT}/mfcc
for x in train test; do
 steps/make_mfcc.sh --cmd "$train_cmd" --nj $njobs \
   data/$x exp/make_mfcc/$x $mfccdir || exit 1;
 steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir || exit 1;
done

# Train monophone models on a subset of the data
utils/subset_data_dir.sh data/train 1000 data/train.1k  || exit 1;
steps/train_mono.sh --nj $njobs --cmd "$train_cmd" data/train.1k data/lang exp/mono  || exit 1;

# Monophone decoding
utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph || exit 1
# note: local/decode.sh calls the command line once for each
# test, and afterwards averages the WERs into (in this case
# exp/mono/decode/
steps/decode.sh --config conf/decode.config --nj $njobs --cmd "$decode_cmd" \
  exp/mono/graph data/test exp/mono/decode

# Get alignments from monophone system.
steps/align_si.sh --nj $njobs --cmd "$train_cmd" \
  data/train data/lang exp/mono exp/mono_ali || exit 1;

# train tri1 [first triphone pass]
steps/train_deltas.sh --cmd "$train_cmd" \
  2000 11000 data/train data/lang exp/mono_ali exp/tri1 || exit 1;

# decode tri1
utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph || exit 1;
steps/decode.sh --config conf/decode.config --nj $njobs --cmd "$decode_cmd" \
  exp/tri1/graph data/test exp/tri1/decode

#draw-tree data/lang/phones.txt exp/tri1/tree | dot -Tps -Gsize=8,10.5 | ps2pdf - tree.pdf


# align tri1
steps/align_si.sh --nj $njobs --cmd "$train_cmd" \
  --use-graphs true data/train data/lang exp/tri1 exp/tri1_ali || exit 1;

# train tri2a [delta+delta-deltas]
steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 \
  data/train data/lang exp/tri1_ali exp/tri2a || exit 1;

# decode tri2a
utils/mkgraph.sh data/lang_test exp/tri2a exp/tri2a/graph
steps/decode.sh --config conf/decode.config --nj $njobs --cmd "$decode_cmd" \
  exp/tri2a/graph data/test exp/tri2a/decode

# train and decode tri2b [LDA+MLLT]
steps/train_lda_mllt.sh --cmd "$train_cmd" 2000 11000 \
  data/train data/lang exp/tri1_ali exp/tri2b || exit 1;
utils/mkgraph.sh data/lang_test exp/tri2b exp/tri2b/graph
steps/decode.sh --config conf/decode.config --nj $njobs --cmd "$decode_cmd" \
  exp/tri2b/graph data/test exp/tri2b/decode

# Align all data with LDA+MLLT system (tri2b)
steps/align_si.sh --nj $njobs --cmd "$train_cmd" --use-graphs true \
   data/train data/lang exp/tri2b exp/tri2b_ali || exit 1;

#  Do MMI on top of LDA+MLLT.
steps/make_denlats.sh --nj $njobs --cmd "$train_cmd" \
  data/train data/lang exp/tri2b exp/tri2b_denlats || exit 1;
steps/train_mmi.sh data/train data/lang exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mmi || exit 1;
steps/decode.sh --config conf/decode.config --iter 4 --nj $njobs --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mmi/decode_it4
steps/decode.sh --config conf/decode.config --iter 3 --nj $njobs --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mmi/decode_it3

# Do the same with boosting.
steps/train_mmi.sh --boost 0.05 data/train data/lang \
   exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mmi_b0.05 || exit 1;
steps/decode.sh --config conf/decode.config --iter 4 --nj $njobs --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mmi_b0.05/decode_it4 || exit 1;
steps/decode.sh --config conf/decode.config --iter 3 --nj $njobs --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mmi_b0.05/decode_it3 || exit 1;

# Do MPE.
steps/train_mpe.sh data/train data/lang exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mpe || exit 1;
steps/decode.sh --config conf/decode.config --iter 4 --nj $njobs --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mpe/decode_it4 || exit 1;
steps/decode.sh --config conf/decode.config --iter 3 --nj $njobs --cmd "$decode_cmd" \
   exp/tri2b/graph data/test exp/tri2b_mpe/decode_it3 || exit 1;


## Do LDA+MLLT+SAT, and decode.
steps/train_sat.sh 2000 11000 data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;
utils/mkgraph.sh data/lang_test exp/tri3b exp/tri3b/graph || exit 1;
steps/decode_fmllr.sh --config conf/decode.config --nj $njobs --cmd "$decode_cmd" \
  exp/tri3b/graph data/test exp/tri3b/decode || exit 1;


# Align all data with LDA+MLLT+SAT system (tri3b)
steps/align_fmllr.sh --nj $njobs --cmd "$train_cmd" --use-graphs true \
  data/train data/lang exp/tri3b exp/tri3b_ali || exit 1;

## MMI on top of tri3b (i.e. LDA+MLLT+SAT+MMI)
steps/make_denlats.sh --config conf/decode.config \
   --nj $njobs --cmd "$train_cmd" --transform-dir exp/tri3b_ali \
  data/train data/lang exp/tri3b exp/tri3b_denlats || exit 1;
steps/train_mmi.sh data/train data/lang exp/tri3b_ali exp/tri3b_denlats exp/tri3b_mmi || exit 1;

steps/decode_fmllr.sh --config conf/decode.config --nj $njobs --cmd "$decode_cmd" \
  --alignment-model exp/tri3b/final.alimdl --adapt-model exp/tri3b/final.mdl \
   exp/tri3b/graph data/test exp/tri3b_mmi/decode || exit 1;

# Do a decoding that uses the exp/tri3b/decode directory to get transforms from.
steps/decode.sh --config conf/decode.config --nj $njobs --cmd "$decode_cmd" \
  --transform-dir exp/tri3b/decode  exp/tri3b/graph data/test exp/tri3b_mmi/decode2 || exit 1;


#first, train UBM for fMMI experiments.
steps/train_diag_ubm.sh --silence-weight 0.5 --nj $njobs --cmd "$train_cmd" \
  250 data/train data/lang exp/tri3b_ali exp/dubm3b

# Next, various fMMI+MMI configurations.
steps/train_mmi_fmmi.sh --learning-rate 0.0025 \
  --boost 0.1 --cmd "$train_cmd" data/train data/lang exp/tri3b_ali exp/dubm3b exp/tri3b_denlats \
  exp/tri3b_fmmi_b || exit 1;

for iter in 3 4 5 6 7 8; do
 steps/decode_fmmi.sh --nj $njobs --config conf/decode.config --cmd "$decode_cmd" --iter $iter \
   --transform-dir exp/tri3b/decode  exp/tri3b/graph data/test exp/tri3b_fmmi_b/decode_it$iter &
done

steps/train_mmi_fmmi.sh --learning-rate 0.001 \
  --boost 0.1 --cmd "$train_cmd" data/train data/lang exp/tri3b_ali exp/dubm3b exp/tri3b_denlats \
  exp/tri3b_fmmi_c || exit 1;

for iter in 3 4 5 6 7 8; do
 steps/decode_fmmi.sh --nj $njobs --config conf/decode.config --cmd "$decode_cmd" --iter $iter \
   --transform-dir exp/tri3b/decode  exp/tri3b/graph data/test exp/tri3b_fmmi_c/decode_it$iter &
done

# for indirect one, use twice the learning rate.
steps/train_mmi_fmmi_indirect.sh --learning-rate 0.002 --schedule "fmmi fmmi fmmi fmmi mmi mmi mmi mmi" \
  --boost 0.1 --cmd "$train_cmd" data/train data/lang exp/tri3b_ali exp/dubm3b exp/tri3b_denlats \
  exp/tri3b_fmmi_d || exit 1;



for iter in 3 4 5 6 7 8; do
 steps/decode_fmmi.sh --nj $njobs --config conf/decode.config --cmd "$decode_cmd" --iter $iter \
   --transform-dir exp/tri3b/decode  exp/tri3b/graph data/test exp/tri3b_fmmi_d/decode_it$iter &
done

local/run_sgmm2.sh --nj $njobs




echo "run_sgmm2.sh finish"




steps/train_sat.sh --cmd "$train_cmd"  \
  2500 15000 data/train data/lang exp/tri3b_ali exp/tri4a || exit 1;

utils/mkgraph.sh data/lang_test exp/tri4a exp/tri4a/graph
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 10 --config conf/decode.config \
  exp/tri4a/graph data/train exp/tri4a/decode_train || exit 1;

steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 10 --config conf/decode.config \
  exp/tri4a/graph data/test exp/tri4a/decode_test

steps/align_fmllr.sh  --cmd "$train_cmd" --nj 10 \
  data/train data/lang exp/tri4a exp/tri4a_ali




steps/train_sat.sh --cmd "$train_cmd" \
  3500 100000 data/train data/lang exp/tri4a_ali exp/tri5a || exit 1;

utils/mkgraph.sh data/lang_test exp/tri5a exp/tri5a/graph || exit 1;
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 10 --config conf/decode.config \
   exp/tri5a/graph data/train exp/tri5a/decode_train || exit 1;
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 10 --config conf/decode.config \
   exp/tri5a/graph data/test exp/tri5a/decode_test || exit 1;

steps/align_fmllr.sh --cmd "$train_cmd" --nj 10 \
  data/train data/lang exp/tri5a exp/tri5a_ali || exit 1;



#rm -rf ./data/train_sp*
#rm -rf ./exp/nnet*

local/chain/run_tdnn.sh

echo "finish!!!!"





