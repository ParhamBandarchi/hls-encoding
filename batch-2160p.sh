#!/bin/bash

list=($(ls | grep -e \.mkv$ -e \.mp4$ -e \.avi$ -e \.mov$))
folder=2

x=1

for i in "${list[@]}"
do
        echo $x - $i
	echo $x/"${#list[@]}" > /home/encoding/source/$folder/status.txt
#	sleep 2

	x=$(($x+1))
	./video-2160p.sh $i && ./audio-2160p.sh $i && rm -f $i
done

echo "done" > /home/encoding/source/$folder/status.txt
