#!/usr/bin/env bash

set -e

# Usage create-vod-hls.sh SOURCE_FILE [OUTPUT_NAME]
[[ ! "${1}" ]] && echo "Usage: create-vod-hls.sh SOURCE_FILE [OUTPUT_NAME]" && exit 1

# comment/add lines here to control which renditions would be created
renditions=(
# resolution  bitrate  audio-rate  channel
  "426x240    400k    128k     2"
  "426x240    400k    128k     6"
  "640x360    600k     144k     2"
  "640x360    600k     144k     6"
  "852x480    1000k    160k     2"
  "852x480    1000k    160k     6"
  "1280x720   1500k    192k     2"
  "1280x720   1500k    192k     6"
  "1920x1080  3500k    256k     2"
  "1920x1080  3500k    256k     6"
  "3840x2160  8000k    320k     2"
  "3840x2160  8000k    320k     6"
)

segment_target_duration=4       # try to create a new segment every X seconds
max_bitrate_ratio=1.07          # maximum accepted bitrate fluctuations
rate_monitor_buffer_ratio=1.5   # maximum buffer size between bitrate conformance checks

#########################################################################

source="${1}"
target="${2}"
if [[ ! "${target}" ]]; then
  target="${source##*/}" # leave only last component of path
  target="${target%.*} | tr '[:upper:]' '[:lower:]'"  # strip extension
  target=($(echo ${target} | tr '[:upper:]' '[:lower:]'))  # convert the target name to lower case
fi
mkdir -p ${target}

initial="$(echo ${target} | head -c 1)" # use target initial to figure out which directory it has to go in to

# checking if it's a series and finding the folder name
if echo ${target} | grep -E '_s[0-9\][0-9\]e[0-9\][0-9\][0-9\][0-9\]'; then
  seriesFolder="$(echo ${target} | sed 's/_s[0-9\][0-9\]e[0-9\][0-9\]e[0-9\][0-9\]//g' | sed 's/_s[0-9\][0-9\]e[0-9\][0-9\][0-9\][0-9\]//g')"
elif echo ${target} | grep -E '_s[0-9\][0-9\]e[0-9\][0-9\][0-9\]'; then
  seriesFolder="$(echo ${target} | sed 's/_s[0-9\][0-9\]e[0-9\][0-9\]e[0-9\][0-9\]//g' | sed 's/_s[0-9\][0-9\]e[0-9\][0-9\][0-9\]//g')"
elif echo ${target} | grep -E '_s[0-9\][0-9\]e[0-9\][0-9\]'; then
  seriesFolder="$(echo ${target} | sed 's/_s[0-9\][0-9\]e[0-9\][0-9\]e[0-9\][0-9\]//g' | sed 's/_s[0-9\][0-9\]e[0-9\][0-9\]//g')"
fi

key_frames_interval="$(echo `ffprobe ${source} 2>&1 | grep -oE '[[:digit:]]+(.[[:digit:]]+)? fps' | grep -oE '[[:digit:]]+(.[[:digit:]]+)?'`*2 | bc || echo '')"
key_frames_interval=${key_frames_interval:-50}
key_frames_interval=$(echo `printf "%.1f\n" $(bc -l <<<"$key_frames_interval/10")`*10 | bc) # round
key_frames_interval=${key_frames_interval%.*} # truncate to integer

# static parameters that are similar for all renditions
static_params="-c:a libfdk_aac -ar 48000"
static_params+=" -g ${key_frames_interval} -keyint_min ${key_frames_interval} -hls_time ${segment_target_duration}"
static_params+=" -hls_playlist_type vod"

# misc params
misc_params="-hide_banner -sn -vn -probesize 250M -y"

master_playlist="#EXTM3U
#EXT-X-VERSION:3
"

cmd=""
for rendition in "${renditions[@]}"; do
  # drop extraneous spaces
  rendition="${rendition/[[:space:]]+/ }"

  # rendition fields
  resolution="$(echo ${rendition} | cut -d ' ' -f 1)"
  bitrate="$(echo ${rendition} | cut -d ' ' -f 2)"
  audiorate="$(echo ${rendition} | cut -d ' ' -f 3)"
  channel="$(echo ${rendition} | cut -d ' ' -f 4)"

  # calculated fields
  width="$(echo ${resolution} | grep -oE '^[[:digit:]]+')"
  height="$(echo ${resolution} | grep -oE '[[:digit:]]+$')"
  maxrate="$(echo "`echo ${bitrate} | grep -oE '[[:digit:]]+'`*${max_bitrate_ratio}" | bc)"
  bufsize="$(echo "`echo ${bitrate} | grep -oE '[[:digit:]]+'`*${rate_monitor_buffer_ratio}" | bc)"
  bandwidth="$(echo ${bitrate} | grep -oE '[[:digit:]]+')000"
  name="${audiorate}-${channel}"

  cmd+=" ${static_params} -ac ${channel}"
  cmd+=" -b:a ${audiorate}"
  cmd+=" -hls_segment_filename ${target}/${name}_%03d.ts ${target}/${name}.m3u8"

  # add rendition entry in the master playlist
  master_playlist+='#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID='\"${height}p\"',NAME="audio",CHANNELS='\"${channel}\"',URI='\"${name}.m3u8\"'\n'

done

# encoding
ffmpeg ${misc_params} -i ${source} ${cmd}

# changing the playlist to include the audio as well
playlist="$(cat ${target}/playlist.m3u8 | sed '1d' | sed '1d')"
master_playlist+=${playlist}

# create master playlist file
echo -e "${master_playlist}" > ${target}/playlist.m3u8

echo "Moving finished directory to encoded"
if [[ ${initial} == [a-z] ]] ; then
  if echo ${target} | grep -E '_s[0-9\][0-9\]e[0-9\][0-9\]'; then
    mkdir -p /home/encoding/encoded/series/${initial}/${seriesFolder}/${target}/
    mv ${target} /home/encoding/encoded/series/${initial}/${seriesFolder}/
  else
    mkdir -p /home/encoding/encoded/movies/${initial}/
    mv ${target} /home/encoding/encoded/movies/${initial}/${target}
  fi
else
  if echo ${target} | grep -E 's[0-9\][0-9\]e[0-9\][0-9\]'; then
    mkdir -p /home/encoding/encoded/series/1/${seriesFolder}/${target}/
    mv ${target} /home/encoding/encoded/series/1/${seriesFolder}/
  else
    mkdir -p /home/encoding/encoded/movies/1/
    mv ${target} /home/encoding/encoded/movies/1/${target}
  fi
fi
