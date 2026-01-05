#!/bin/bash
#
# Carambus YouTube Live Streaming Script for Raspberry Pi 4
# This script runs on the scoreboard Raspberry Pi and streams to YouTube
#
# Features:
# - Captures video from USB camera (Logitech C922)
# - Renders scoreboard overlay from local Rails server
# - Composites video + overlay with FFmpeg
# - Streams to YouTube via RTMP
# - Uses software encoding (libx264) for YouTube compatibility
#
# Usage:
#   carambus-stream.sh [table_id]
#
# Example:
#   carambus-stream.sh 2  # For Rails Table with ID 2 (may be named "Tisch 6")
#
# Configuration:
#   Reads from /etc/carambus/stream-table-[table_id].conf
#
# Note: table_id is the Rails database ID (Table.id), not the table name/number.
#       For example: Table with id=2 might have name="Tisch 6"
#

set -e  # Exit on error

# ============================================================================
# Configuration
# ============================================================================

# TABLE_NUMBER is used for file names (e.g., "6" for "Tisch 6")
# TABLE_ID is the Rails database ID (e.g., 2 for the table record)
TABLE_NUMBER=${1:-2}
CONFIG_FILE="/etc/carambus/stream-table-${TABLE_NUMBER}.conf"
LOG_FILE="/var/log/carambus/stream-table-${TABLE_NUMBER}.log"
OVERLAY_IMAGE="/tmp/carambus-overlay-table-${TABLE_NUMBER}.png"
OVERLAY_TEXT_FILE="/tmp/carambus-overlay-text-table-${TABLE_NUMBER}.txt"
XVFB_DISPLAY=":${TABLE_NUMBER}"

# Ensure log directory exists
mkdir -p /var/log/carambus

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# TABLE_ID should be set in the config file - this is the Rails DB ID
if [ -z "$TABLE_ID" ]; then
    echo "ERROR: TABLE_ID not set in $CONFIG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

# Validate required configuration
if [ -z "$YOUTUBE_KEY" ]; then
    echo "ERROR: YOUTUBE_KEY not set in $CONFIG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

# Default values if not set in config
CAMERA_DEVICE=${CAMERA_DEVICE:-/dev/video0}
CAMERA_WIDTH=${CAMERA_WIDTH:-1280}
CAMERA_HEIGHT=${CAMERA_HEIGHT:-720}
CAMERA_FPS=${CAMERA_FPS:-60}
OVERLAY_ENABLED=${OVERLAY_ENABLED:-true}
OVERLAY_POSITION=${OVERLAY_POSITION:-bottom}
OVERLAY_HEIGHT=${OVERLAY_HEIGHT:-200}
VIDEO_BITRATE=${VIDEO_BITRATE:-2000}
AUDIO_BITRATE=${AUDIO_BITRATE:-128}

# ============================================================================
# Functions
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

cleanup() {
    log "Cleaning up..."
    
    # Note: Overlay PNG is managed by carambus-overlay-receiver service
    # We don't remove it here so it's available for the next stream start
    
    log "Cleanup complete"
}

trap cleanup EXIT INT TERM

check_camera() {
    if [ ! -e "$CAMERA_DEVICE" ]; then
        log "ERROR: Camera device not found: $CAMERA_DEVICE"
        log "Available video devices:"
        ls -l /dev/video* | tee -a "$LOG_FILE" || log "No video devices found"
        return 1
    fi
    
    # Check if camera is accessible
    if ! v4l2-ctl --device="$CAMERA_DEVICE" --list-formats-ext > /dev/null 2>&1; then
        log "ERROR: Cannot access camera at $CAMERA_DEVICE"
        return 1
    fi
    
    log "Camera OK: $CAMERA_DEVICE"
    return 0
}

check_network() {
    # Ping YouTube RTMP server
    if ! ping -c 1 a.rtmp.youtube.com > /dev/null 2>&1; then
        log "WARNING: Cannot reach YouTube RTMP server"
        return 1
    fi
    
    log "Network OK"
    return 0
}

start_xvfb() {
    log "Starting virtual framebuffer on display $XVFB_DISPLAY..."
    
    # Kill any existing Xvfb on this display
    pkill -f "Xvfb $XVFB_DISPLAY" 2>/dev/null || true
    sleep 1
    
    # Start Xvfb
    Xvfb "$XVFB_DISPLAY" -screen 0 "${CAMERA_WIDTH}x${OVERLAY_HEIGHT}x24" >> "$LOG_FILE" 2>&1 &
    XVFB_PID=$!
    
    # Wait for Xvfb to start
    sleep 2
    
    if ! ps -p $XVFB_PID > /dev/null; then
        log "ERROR: Failed to start Xvfb"
        return 1
    fi
    
    log "Xvfb started (PID: $XVFB_PID)"
    return 0
}

check_overlay_file() {
    # Overlay PNG is provided by carambus-overlay-receiver service via ActionCable
    # This function just verifies the file exists and is being updated
    log "Checking for overlay PNG file (provided by overlay receiver service)..."
    
    if [ ! -f "$OVERLAY_IMAGE" ]; then
        log "WARNING: Overlay PNG not found yet at $OVERLAY_IMAGE"
        log "         The carambus-overlay-receiver@${TABLE_NUMBER}.service should be running"
        log "         Creating blank overlay as fallback..."
        convert -size "${CAMERA_WIDTH}x${OVERLAY_HEIGHT}" xc:transparent "$OVERLAY_IMAGE"
        return 1
    fi
    
    # Check file age (should be updated recently by receiver service)
    FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$OVERLAY_IMAGE" 2>/dev/null || stat -f %m "$OVERLAY_IMAGE" 2>/dev/null || echo 0) ))
    
    if [ $FILE_AGE -gt 30 ]; then
        log "WARNING: Overlay PNG is stale (${FILE_AGE}s old)"
        log "         Check carambus-overlay-receiver@${TABLE_NUMBER}.service status"
    else
        log "Overlay PNG OK (${FILE_AGE}s old)"
    fi
    
    return 0
}

start_stream() {
    log "=========================================="
    log "Starting Carambus Stream"
    log "=========================================="
    log "Table: ${TABLE_NUMBER} (name: Tisch ${TABLE_NUMBER}, Rails ID: ${TABLE_ID})"
    log "Camera: $CAMERA_DEVICE (${CAMERA_WIDTH}x${CAMERA_HEIGHT}@${CAMERA_FPS}fps)"
    log "Overlay: $OVERLAY_ENABLED"
    log "Video Bitrate: ${VIDEO_BITRATE}k"
    log "=========================================="
    
    # Check prerequisites
    check_camera || exit 1
    check_network || log "WARNING: Network check failed, continuing anyway..."
    
    # Check overlay file if enabled (provided by carambus-overlay-receiver service)
    if [ "$OVERLAY_ENABLED" = "true" ]; then
        check_overlay_file || log "WARNING: Overlay file check failed, continuing with blank overlay"
    fi
    
    # Build FFmpeg command
    RTMP_URL="rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_KEY}"
    
    log "Starting FFmpeg..."
    log "RTMP URL: rtmp://a.rtmp.youtube.com/live2/[REDACTED]"
    
    # Detect available camera formats and choose best one
    # Priority: MJPEG (best for 720p@30fps) > H264 > YUYV (worst, limited to 10fps at 720p)
    CAMERA_FORMATS=$(v4l2-ctl --device="$CAMERA_DEVICE" --list-formats-ext 2>/dev/null)
    
    # Determine input format and encoding strategy
    # Check for MJPEG support (preferred for Logitech C922 at 720p)
    if echo "$CAMERA_FORMATS" | grep -i "MJPG" > /dev/null 2>&1; then
        INPUT_FORMAT="mjpeg"
        USE_HW_DECODE=false
        log "Camera using MJPEG format (optimal for 720p@30fps)"
    elif echo "$CAMERA_FORMATS" | grep -i "H264" > /dev/null 2>&1; then
        INPUT_FORMAT="h264"
        USE_HW_DECODE=true
        log "Camera supports H.264, using hardware decoding"
    else
        INPUT_FORMAT="yuyv422"
        USE_HW_DECODE=false
        log "WARNING: Camera using YUYV (limited to 10fps at 720p on C922)"
    fi
    
    # CONFIRMED: Hardware encoder does NOT work with YouTube Live
    # Tested multiple times with h264_v4l2m2m - YouTube only shows logo, never video
    # Must use libx264 software encoder for YouTube compatibility
    VIDEO_ENCODER="libx264"
    log "Using software encoder: libx264 (YouTube requires this)"
    
    if [ "$OVERLAY_ENABLED" = "true" ]; then
        # Text-based overlay using FFmpeg drawtext filter
        # Fetches text data from Rails server endpoint
        # Text file is updated by background process
        
        log "Using text overlay: ${OVERLAY_TEXT_FILE}"
        
        # Create initial text file if it doesn't exist
        if [ ! -f "$OVERLAY_TEXT_FILE" ]; then
            echo "Loading..." > "$OVERLAY_TEXT_FILE"
        fi
        
        # Get location MD5 and server URL from config
        LOCATION_MD5=${LOCATION_MD5:-"0819bf0d7893e629200c20497ef9cfff"}
        RAILS_SERVER=${SERVER_URL:-"http://192.168.178.106:3000"}
        
        # Start background process to update text file
        (
            while true; do
                curl -sf "${RAILS_SERVER}/locations/${LOCATION_MD5}/scoreboard_text?table_id=${TABLE_ID}" \
                    > "${OVERLAY_TEXT_FILE}.tmp" 2>/dev/null && \
                    mv "${OVERLAY_TEXT_FILE}.tmp" "${OVERLAY_TEXT_FILE}"
                sleep 1
            done
        ) &
        TEXT_UPDATER_PID=$!
        
        # Build drawtext filter with monospace font for alignment
        # Use DejaVuSansMono for fixed-width characters
        # Font size scales with resolution: 720p=24px, 1080p=32px, 360p=16px
        if [ "$CAMERA_HEIGHT" -ge 1080 ]; then
            FONT_SIZE=32
        elif [ "$CAMERA_HEIGHT" -ge 720 ]; then
            FONT_SIZE=24
        else
            FONT_SIZE=16
        fi
        DRAWTEXT_FILTER="drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:textfile='${OVERLAY_TEXT_FILE}':reload=1:fontsize=${FONT_SIZE}:fontcolor=white:box=1:boxcolor=black@0.8:boxborderw=15:x=15:y=h-th-15"
        
        # Stream with text overlay
        # YouTube requires keyframes every 4 seconds or less (GOP size)
        # At 30fps: -g 60 = keyframe every 2 seconds
        ffmpeg \
            -f v4l2 -input_format "$INPUT_FORMAT" -video_size "${CAMERA_WIDTH}x${CAMERA_HEIGHT}" -framerate "$CAMERA_FPS" \
            -i "$CAMERA_DEVICE" \
            -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
            -filter_complex "[0:v]${DRAWTEXT_FILTER}[out]" \
            -map "[out]" -map 1:a \
            -c:v "$VIDEO_ENCODER" -b:v "${VIDEO_BITRATE}k" -maxrate "$((VIDEO_BITRATE + 500))k" -bufsize "$((VIDEO_BITRATE * 2))k" \
            -c:a aac -b:a "${AUDIO_BITRATE}k" \
            -pix_fmt yuv420p -color_range tv -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
            -g 60 -keyint_min 60 -sc_threshold 0 \
            -preset veryfast -tune zerolatency -threads 4 -thread_type slice \
            -f flv "$RTMP_URL" \
            >> "$LOG_FILE" 2>&1
        
        # Kill text updater on exit
        kill $TEXT_UPDATER_PID 2>/dev/null || true
    else
        # Stream without overlay
        if [ "$USE_HW_DECODE" = "true" ]; then
            ffmpeg \
                -f v4l2 -input_format "$INPUT_FORMAT" -video_size "${CAMERA_WIDTH}x${CAMERA_HEIGHT}" -framerate "$CAMERA_FPS" \
                -i "$CAMERA_DEVICE" \
                -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
                -map 0:v -map 1:a \
                -c:v "$VIDEO_ENCODER" -b:v "${VIDEO_BITRATE}k" -maxrate "$((VIDEO_BITRATE + 500))k" -bufsize "$((VIDEO_BITRATE * 2))k" \
                -c:a aac -b:a "${AUDIO_BITRATE}k" \
                -pix_fmt yuv420p -g 120 -keyint_min 120 -sc_threshold 0 \
                -preset ultrafast -tune zerolatency \
                -f flv "$RTMP_URL" \
                >> "$LOG_FILE" 2>&1
        else
            ffmpeg \
                -f v4l2 -input_format "$INPUT_FORMAT" -video_size "${CAMERA_WIDTH}x${CAMERA_HEIGHT}" -framerate "$CAMERA_FPS" \
                -i "$CAMERA_DEVICE" \
                -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
                -filter_complex "[0:v]scale=${CAMERA_WIDTH}:${CAMERA_HEIGHT}:flags=lanczos,format=yuv420p,setrange=tv,setparams=colorspace=bt709:color_trc=bt709:color_primaries=bt709[vout]" \
                -map "[vout]" -map 1:a \
                -c:v "$VIDEO_ENCODER" -b:v "${VIDEO_BITRATE}k" -maxrate "$((VIDEO_BITRATE + 500))k" -bufsize "$((VIDEO_BITRATE * 2))k" \
                -c:a aac -b:a "${AUDIO_BITRATE}k" \
                -pix_fmt yuv420p -color_range tv -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
                -profile:v high -level 4.0 \
                -g 120 -keyint_min 120 -sc_threshold 0 \
                -preset ultrafast -tune zerolatency \
                -f flv "$RTMP_URL" \
                >> "$LOG_FILE" 2>&1
        fi
    fi
    
    # If FFmpeg exits, log it
    EXIT_CODE=$?
    log "FFmpeg exited with code: $EXIT_CODE"
    exit $EXIT_CODE
}

# ============================================================================
# Main
# ============================================================================

start_stream


