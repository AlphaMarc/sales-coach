#!/bin/bash
set -e

WHISPER_VERSION="v1.5.4"

echo "=== Building whisper.cpp ==="

# Clone if not exists
if [ ! -d "whisper.cpp" ]; then
  echo "Cloning whisper.cpp..."
  git clone --depth 1 --branch $WHISPER_VERSION https://github.com/ggerganov/whisper.cpp.git
fi

cd whisper.cpp

# Build for Apple Silicon
echo "Building whisper.cpp for Apple Silicon..."
make clean
CFLAGS="-O3 -DNDEBUG" make main

# Verify build
if [ ! -f "main" ]; then
  echo "Error: whisper.cpp build failed"
  exit 1
fi

echo "whisper.cpp binary built successfully"

# Download model if not cached
if [ ! -f "models/ggml-base.en.bin" ]; then
  echo "Downloading whisper base.en model..."
  bash ./models/download-ggml-model.sh base.en
fi

# Verify model
if [ ! -f "models/ggml-base.en.bin" ]; then
  echo "Error: Failed to download whisper model"
  exit 1
fi

echo "whisper.cpp build complete"
echo "Binary: $(pwd)/main"
echo "Model: $(pwd)/models/ggml-base.en.bin"

# Copy to SalesCoach Resources
cd ..
echo "Copying binaries to SalesCoach/Resources..."
cp whisper.cpp/main SalesCoach/Resources/whisper-cli
cp whisper.cpp/models/ggml-base.en.bin SalesCoach/Resources/

# Download base model (multilingual) if needed
if [ ! -f "SalesCoach/Resources/ggml-base.bin" ]; then
  echo "Downloading whisper base model (multilingual)..."
  cd whisper.cpp
  bash ./models/download-ggml-model.sh base
  cd ..
  cp whisper.cpp/models/ggml-base.bin SalesCoach/Resources/
fi

echo "=== whisper.cpp setup complete ==="
echo "Resources copied to SalesCoach/Resources/"

