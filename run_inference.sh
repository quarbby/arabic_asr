#!/bin/bash

downsamplefiles () {

	printf "Installing ffmpeg\n\n";

	apt-get install ffmpeg;
	
	if [ "$?" -eq "0" ]
	then
		printf "FFMPEG installed\n";
	else
		$version = exec "ffmpeg -V";
		if [ -z "$version" ]
		then
			printf "ffmpeg version: $version\n";
			continue
		else
			printf "ffmpeg not installed\n";
			exit
		fi
	fi
	
	printf "Renaming audio files\n\n";
	
	for file in $data_folder/wav/*.wav
	do
		echo $file
		mv "$file" "${file// /_}"
	done
	
	printf "Audio files renamed\n\n";
	
	for file in $data_folder/wav/*.wav
	do
		ffmpeg -i $file -ar 16000 $file -y
	done
}

usage () {
	echo "usage: bash run_inference.sh [[[-o output_file] [-d data_folder] [-t original_transcript] | [-h]]"
}

data_folder=data/test_data
output_file=output_transcript
original_transcript=/home/user/Desktop/arabic-speech-corpus/test_set/orthographic-transcript.txt

while :; do
	case $1 in
		-o | --output_file )	shift
													output_file=$1
													;;
		-d | --data_folder )	shift
													data_folder=$1
													;;
		-t | --transcript )		shift
													original_transcript=$1
													;;
		-s | --downsample )		downsamplefiles
													;;
		-h | --help )					usage
													exit
													;;
		* )										break
	esac
	shift
done

printf "Creating wav.scp\n" ;

rm -rf $data_folder/wav.scp
exec 3<> $data_folder/wav.scp

let "counter = 1"

for file in $data_folder/wav/*.wav
do
	printf -v temp "%05d" $counter
	echo "$temp $file" >&3
	let "counter = counter + 1"
done

exec #>&-

printf "wav.scp created\n\n" ;
printf "creating utt2spk\n" ;

rm -rf $data_folder/utt2spk
exec 3<> $data_folder/utt2spk

let "counter = 1"

for file in $data_folder/wav/*.wav
do
	printf -v temp "%05d" $counter
	echo "$temp $temp" >&3
	let "counter = counter + 1"
done

exec #>&-

printf "utt2spk created\n\n" ;
printf "creating spk2utt\n" ;

rm -rf $data_folder/spk2utt
exec 3<> $data_folder/spk2utt

let "counter = 1"

for file in $data_folder/wav/*.wav
do
	printf -v temp "%05d" $counter
	echo "$temp $temp" >&3
	let "counter = counter + 1"
done

exec #>&-

printf "spk2utt created\n\n" ;

echo "Sourcing path";
source ./path.sh &&
echo "Sourcing path complete";
printf "\n\n";

echo "Extracting MFCC features";
steps/make_mfcc.sh --cmd "run.pl" --nj 1 --mfcc-config conf/mfcc_hires.conf $data_folder exp/make_hires/test_data mfcc &&
echo "MFCC features extracted";
printf "\n\n";

echo "Extracting i-vectors";
steps/online/nnet2/extract_ivectors_online.sh --cmd "run.pl" --nj 1 $data_folder exp/nnet3/extractor exp/nnet3/ivectors_test_data &&
echo "i-vectors Extracted";
printf "\n\n";

echo "Decoding...";
steps/nnet3/decode.sh --nj 1 --cmd run.pl --acwt 1.0 --post-decode-acwt 10.0 --online-ivector-dir exp/nnet3/ivectors_test_data exp/mer80/chain/tdnn_7b/graph_tg $data_folder exp/mer80/chain/tdnn_7b/decode_test_data &&
echo "Decoding complete";
printf "\n\n";

echo "Transcribing...";
lattice-scale --inv-acoustic-scale=8.0 "ark:gunzip -c exp/mer80/chain/tdnn_7b/decode_test_data/lat.*.gz|" ark:- | lattice-add-penalty --word-ins-penalty=0.0 ark:- ark:- | lattice-prune --beam=8 ark:- ark:- | lattice-mbr-decode --word-symbol-table=exp/mer80/chain/tdnn_7b/graph_tg/words.txt ark:- ark,t:- | utils/int2sym.pl -f 2- exp/mer80/chain/tdnn_7b/graph_tg/words.txt > $output_file &&
echo "Transcribing complete";
printf "\n\n";

# module load python/3.7.3
python3 check_model_accuracy.py $output_file $original_transcript

echo "Script completed"
