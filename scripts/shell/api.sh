#!/usr/bin/env bash
# /qompassai/Diver/scripts/api.sh
# Qompass AI Diver API Script
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
function _get_available_downloader
{
  if command -v curl &> /dev/null; then
    echo "curl"
  elif command -v wget &> /dev/null; then
    echo "wget"
  else
    echo "none"
  fi
}
function download_file
{
  local URL="$1" OUTPUT_FILE="$2"
  if command -v curl &> /dev/null; then
    curl -fsSL -o "$OUTPUT_FILE" "$URL"
    debug "Downloaded file from $URL to $OUTPUT_FILE using cURL"
  elif command -v wget &> /dev/null; then
    wget --quiet --output-document="$OUTPUT_FILE" "$URL"
    debug "Downloaded file from $URL to $OUTPUT_FILE using wget"
  else
    fatal --status=3 "No downloader found. Current options are cURL and wget"
  fi
}
function run_api_call
{
  local URL="$1"
  local downloader
  downloader=$(_get_available_downloader)
  if [[ $downloader == "none" ]]; then
    fatal --status=3 "No downloader found. Available options are cURL and wget"
  fi
  local tmpfile
  tmpfile="$(mktemp)"
  download_file "$URL" "$tmpfile"
  local response
  response=$(< "$tmpfile")
  rm -f "$tmpfile"
  debug "API call to $URL returned response: $response"
  echo "$response"
}
