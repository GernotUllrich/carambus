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
# - Uses hardware encoding (h264_v4l2m2m) for efficiency
#
# Usage:
#   carambus-stream.sh [table_number]
#
# Configuration:
#   Reads from /etc/carambus/stream-table-N.conf
#

set -e  # Exit on error

# ============================================================================
# Configuration
# ============================================================================

TABLE_NUMBER=${1:-1}
CONFIG_FILE="/etc/carambus/stream-table-${TABLE_NUMBER}.conf"
LOG_FILE="/var/log/carambus/stream-table-${TABLE_NUMBER}.log"
OVERLAY_IMAGE="/tmp/carambus-overlay-table-${TABLE_NUMBER}.png"
XVFB_DISPLAY=":${TABLE_NUMBER}"

# Ensure log directory exists
mkdir -p /var/log/carambus

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

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
    
    # Kill overlay update loop
    if [ -n "$OVERLAY_PID" ]; then
        kill $OVERLAY_PID 2>/dev/null || true
    fi
    
    # Kill Xvfb
    if [ -n "$XVFB_PID" ]; then
        kill $XVFB_PID 2>/dev/null || true
    fi
    
    # Remove temporary files
    rm -f "$OVERLAY_IMAGE" 2>/dev/null || true
    
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

update_overlay_loop() {
    log "Starting overlay update loop..."
    
    export DISPLAY="$XVFB_DISPLAY"
    
    # Detect chromium command
    if command -v chromium >/dev/null 2>&1; then
        BROWSER_CMD="chromium"
    elif command -v chromium-browser >/dev/null 2>&1; then
        BROWSER_CMD="chromium-browser"
    else
        log "ERROR: Chromium not found"
        return 1
    fi
    
    # Update overlay every 2 seconds
    while true; do
        $BROWSER_CMD \
            --headless \
            --disable-gpu \
            --screenshot="$OVERLAY_IMAGE" \
            --window-size="${CAMERA_WIDTH},${OVERLAY_HEIGHT}" \
            --virtual-time-budget=2000 \
            --hide-scrollbars \
            "$OVERLAY_URL" >> "$LOG_FILE" 2>&1 || true
        
        sleep 2
    done
}

start_stream() {
    log "=========================================="
    log "Starting Carambus Stream"
    log "=========================================="
    log "Table: $TABLE_NUMBER"
    log "Camera: $CAMERA_DEVICE (${CAMERA_WIDTH}x${CAMERA_HEIGHT}@${CAMERA_FPS}fps)"
    log "Overlay: $OVERLAY_ENABLED"
    log "Video Bitrate: ${VIDEO_BITRATE}k"
    log "=========================================="
    
    # Check prerequisites
    check_camera || exit 1
    check_network || log "WARNING: Network check failed, continuing anyway..."
    
    # Start Xvfb if overlay is enabled
    if [ "$OVERLAY_ENABLED" = "true" ]; then
        start_xvfb || exit 1
        
        # Start overlay update loop in background
        update_overlay_loop &
        OVERLAY_PID=$!
        
        log "Overlay update loop started (PID: $OVERLAY_PID)"
        
        # Wait for first overlay image
        log "Waiting for first overlay image..."
        for i in {1..10}; do
            if [ -f "$OVERLAY_IMAGE" ]; then
                log "Overlay image ready"
                break
            fi
            sleep 1
        done
        
        if [ ! -f "$OVERLAY_IMAGE" ]; then
            log "WARNING: Overlay image not created, creating blank overlay"
            convert -size "${CAMERA_WIDTH}x${OVERLAY_HEIGHT}" xc:transparent "$OVERLAY_IMAGE"
        fi
    fi
    
    # Build FFmpeg command
    RTMP_URL="rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_KEY}"
    
    log "Starting FFmpeg..."
    log "RTMP URL: rtmp://a.rtmp.youtube.com/live2/[REDACTED]"
    
    # Detect available camera formats
    CAMERA_FORMATS=$(v4l2-ctl --device="$CAMERA_DEVICE" --list-formats-ext 2>/dev/null | grep -E "YUYV|MJPEG|H264" | head -1)
    
    # Determine input format and encoding strategy
    if echo "$CAMERA_FORMATS" | grep -q "H264"; then
        INPUT_FORMAT="h264"
        USE_HW_DECODE=true
        log "Camera supports H.264, using hardware decoding"
    elif echo "$CAMERA_FORMATS" | grep -q "MJPEG"; then
        INPUT_FORMAT="mjpeg"
        USE_HW_DECODE=false
        log "Camera supports MJPEG, using software decoding"
    else
        INPUT_FORMAT="yuyv422"
        USE_HW_DECODE=false
        log "Camera using YUYV, using software encoding"
    fi
    
    # Check for hardware encoder availability
    if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q h264_v4l2m2m; then
        VIDEO_ENCODER="h264_v4l2m2m"
        log "Using hardware encoder: h264_v4l2m2m"
    elif ffmpeg -hide_banner -encoders 2>/dev/null | grep -q h264_omx; then
        VIDEO_ENCODER="h264_omx"
        log "Using hardware encoder: h264_omx"
    else
        VIDEO_ENCODER="libx264"
        log "Using software encoder: libx264 (may be slow!)"
    fi
    
    if [ "$OVERLAY_ENABLED" = "true" ]; then
        # Stream with overlay
        if [ "$USE_HW_DECODE" = "true" ]; then
            # Hardware decode path
            ffmpeg \
                -f v4l2 -input_format "$INPUT_FORMAT" -video_size "${CAMERA_WIDTH}x${CAMERA_HEIGHT}" -framerate "$CAMERA_FPS" \
                -i "$CAMERA_DEVICE" \
                -loop 1 -framerate 1 -i "$OVERLAY_IMAGE" \
                -filter_complex "[0:v]scale=${CAMERA_WIDTH}:${CAMERA_HEIGHT}[cam];[cam][1:v]overlay=x=0:y=main_h-overlay_h:shortest=1[out]" \
                -map "[out]" \
                -c:v "$VIDEO_ENCODER" -b:v "${VIDEO_BITRATE}k" -maxrate "$((VIDEO_BITRATE + 500))k" -bufsize "$((VIDEO_BITRATE * 2))k" \
                -pix_fmt yuv420p -g 120 -keyint_min 120 -sc_threshold 0 \
                -preset ultrafast -tune zerolatency \
                -f flv "$RTMP_URL" \
                >> "$LOG_FILE" 2>&1
        else
            # Software decode path (YUYV/MJPEG)
            ffmpeg \
                -f v4l2 -input_format "$INPUT_FORMAT" -video_size "${CAMERA_WIDTH}x${CAMERA_HEIGHT}" -framerate "$CAMERA_FPS" \
                -i "$CAMERA_DEVICE" \
                -loop 1 -framerate 1 -i "$OVERLAY_IMAGE" \
                -filter_complex "[0:v]format=yuv420p,scale=${CAMERA_WIDTH}:${CAMERA_HEIGHT}[cam];[cam][1:v]overlay=x=0:y=main_h-overlay_h:shortest=1[out]" \
                -map "[out]" \
                -c:v "$VIDEO_ENCODER" -b:v "${VIDEO_BITRATE}k" -maxrate "$((VIDEO_BITRATE + 500))k" -bufsize "$((VIDEO_BITRATE * 2))k" \
                -pix_fmt yuv420p -g 120 -keyint_min 120 -sc_threshold 0 \
                -preset ultrafast -tune zerolatency \
                -f flv "$RTMP_URL" \
                >> "$LOG_FILE" 2>&1
        fi
    else
        # Stream without overlay
        if [ "$USE_HW_DECODE" = "true" ]; then
            ffmpeg \
                -f v4l2 -input_format "$INPUT_FORMAT" -video_size "${CAMERA_WIDTH}x${CAMERA_HEIGHT}" -framerate "$CAMERA_FPS" \
                -i "$CAMERA_DEVICE" \
                -c:v "$VIDEO_ENCODER" -b:v "${VIDEO_BITRATE}k" -maxrate "$((VIDEO_BITRATE + 500))k" -bufsize "$((VIDEO_BITRATE * 2))k" \
                -pix_fmt yuv420p -g 120 -keyint_min 120 -sc_threshold 0 \
                -preset ultrafast -tune zerolatency \
                -f flv "$RTMP_URL" \
                >> "$LOG_FILE" 2>&1
        else
            ffmpeg \
                -f v4l2 -input_format "$INPUT_FORMAT" -video_size "${CAMERA_WIDTH}x${CAMERA_HEIGHT}" -framerate "$CAMERA_FPS" \
                -i "$CAMERA_DEVICE" \
                -c:v "$VIDEO_ENCODER" -b:v "${VIDEO_BITRATE}k" -maxrate "$((VIDEO_BITRATE + 500))k" -bufsize "$((VIDEO_BITRATE * 2))k" \
                -pix_fmt yuv420p -g 120 -keyint_min 120 -sc_threshold 0 \
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


