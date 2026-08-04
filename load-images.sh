#!/bin/bash

ARCHIVE="docker-images.tar.gz"
OUTPUT_DIR="./docker-images"

if [ ! -f "$ARCHIVE" ]; then
  echo "Error: $ARCHIVE not found!"
  exit 1
fi

echo "Extracting $ARCHIVE..."
mkdir -p "$OUTPUT_DIR"
tar -xzvf "$ARCHIVE" -C "$OUTPUT_DIR"

for tar_file in "$OUTPUT_DIR"/*.tar; do
  if [ -f "$tar_file" ]; then
    echo "Loading $tar_file..."
    docker load -i "$tar_file"
  fi
done

echo "Cleaning up..."
rm -rf "$OUTPUT_DIR"

echo "Done! All images loaded."