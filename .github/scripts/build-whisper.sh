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

# Build for Apple Silicon (skip if already built)
if [ ! -f "main" ]; then
  echo "Building whisper.cpp for Apple Silicon..."
  make clean
  CFLAGS="-O3 -DNDEBUG" make main
  
  # Verify build
  if [ ! -f "main" ]; then
    echo "Error: whisper.cpp build failed"
    exit 1
  fi
  echo "whisper.cpp binary built successfully"
else
  echo "whisper.cpp binary already exists, skipping build"
fi

# Download English-only model if not cached
if [ ! -f "models/ggml-base.en.bin" ]; then
  echo "Downloading whisper base.en model..."
  bash ./models/download-ggml-model.sh base.en
fi

# Verify English model
if [ ! -f "models/ggml-base.en.bin" ]; then
  echo "Error: Failed to download whisper base.en model"
  exit 1
fi

# Download multilingual model if not cached
if [ ! -f "models/ggml-base.bin" ]; then
  echo "Downloading whisper base model (multilingual)..."
  bash ./models/download-ggml-model.sh base
fi

# Verify multilingual model
if [ ! -f "models/ggml-base.bin" ]; then
  echo "Error: Failed to download whisper base model (multilingual)"
  exit 1
fi

echo "whisper.cpp build complete"
echo "Binary: $(pwd)/main"
echo "Model (en): $(pwd)/models/ggml-base.en.bin"
echo "Model (multilingual): $(pwd)/models/ggml-base.bin"

# Copy to SalesCoach Resources
cd ..
echo "Copying binaries to SalesCoach/Resources..."
mkdir -p SalesCoach/Resources

cp whisper.cpp/main SalesCoach/Resources/whisper-cli
cp whisper.cpp/models/ggml-base.en.bin SalesCoach/Resources/
cp whisper.cpp/models/ggml-base.bin SalesCoach/Resources/

# Verify all files copied
echo "=== Verifying SalesCoach/Resources ==="
ls -la SalesCoach/Resources/

if [ ! -f "SalesCoach/Resources/whisper-cli" ]; then
  echo "Error: whisper-cli not copied"
  exit 1
fi

if [ ! -f "SalesCoach/Resources/ggml-base.en.bin" ]; then
  echo "Error: ggml-base.en.bin not copied"
  exit 1
fi

if [ ! -f "SalesCoach/Resources/ggml-base.bin" ]; then
  echo "Error: ggml-base.bin not copied"
  exit 1
fi

echo "=== whisper.cpp setup complete ==="
echo "All resources copied to SalesCoach/Resources/"

