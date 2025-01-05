#!/bin/bash

# Function to convert timestamp (HH:MM:SS) to seconds
timestamp_to_seconds() {
    local timestamp=$1
    local hours minutes seconds

    if [[ $timestamp =~ ([0-9]+):([0-9]+):([0-9]+) ]]; then
        # Remove leading zeros and convert to decimal
        hours=$((10#${BASH_REMATCH[1]}))
        minutes=$((10#${BASH_REMATCH[2]}))
        seconds=$((10#${BASH_REMATCH[3]}))
        echo $((hours * 3600 + minutes * 60 + seconds))
    else
        echo "Invalid timestamp format. Use HH:MM:SS" >&2
        exit 1
    fi
}

usage() {
    echo "Usage: $0 [options] <youtube_url>"
    echo "Options:"
    echo "  -s, --start HH:MM:SS    Start time (default: 00:00:00)"
    echo "  -e, --end HH:MM:SS      End time"
    echo "  -o, --output FILE       Output filename (default: output.mp4)"
    echo "  -a, --audio-only        Download audio only (output will be .mp3)"
    echo "Example:"
    echo "  $0 -s 00:01:00 -e 00:02:00 -o clip.mp4 https://youtube.com/watch?v=..."
}

# Default values
start_time="00:00:00"
end_time=""
output_file="output.mp4"
audio_only=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--start)
            start_time="$2"
            shift 2
            ;;
        -e|--end)
            end_time="$2"
            shift 2
            ;;
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        -a|--audio-only)
            audio_only=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            youtube_url="$1"
            shift
            ;;
    esac
done

# Check if YouTube URL is provided
if [ -z "$youtube_url" ]; then
    echo "Error: YouTube URL is required"
    usage
    exit 1
fi

# Convert timestamps to seconds
start_seconds=$(timestamp_to_seconds "$start_time")

if [ -n "$end_time" ]; then
    end_seconds=$(timestamp_to_seconds "$end_time")
    duration=$((end_seconds - start_seconds))
    if [ $duration -le 0 ]; then
        echo "Error: End time must be after start time"
        exit 1
    fi
    duration_param="-t $duration"
else
    duration_param=""
fi

# Get video URLs
echo "Fetching video URLs..."
urls=$(youtube-dl --youtube-skip-dash-manifest -g "$youtube_url")

if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch video URLs"
    exit 1
fi

# Split URLs into array
IFS=$'\n' read -r -d '' -a url_array <<< "$urls"

if $audio_only; then
    # Change output extension to mp3 if not already specified
    if [[ ! "$output_file" =~ \.mp3$ ]]; then
        output_file="${output_file%.*}.mp3"
    fi

    echo "Downloading audio to: $output_file"
    ffmpeg -ss "$start_time" -i "${url_array[1]}" $duration_param \
        -c:a libmp3lame -q:a 2 "$output_file"
else
    # Change output extension to mp4 if not already specified
    if [[ ! "$output_file" =~ \.(mp4|mkv)$ ]]; then
        output_file="${output_file%.*}.mp4"
    fi

    echo "Downloading video to: $output_file"
    ffmpeg -ss "$start_time" -i "${url_array[0]}" \
        -ss "$start_time" -i "${url_array[1]}" \
        $duration_param \
        -map 0:v -map 1:a \
        -c:v libx264 -c:a aac "$output_file"
fi

if [ $? -eq 0 ]; then
    echo "Download completed: $output_file"
else
    echo "Error: Download failed"
    exit 1
fi
