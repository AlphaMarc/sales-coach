#!/bin/bash
set -e

WHISPER_VERSION="v1.7.4"

echo "=== Building whisper.cpp ==="

# Clone if not exists
if [ ! -d "whisper.cpp" ]; then
  echo "Cloning whisper.cpp..."
  git clone --depth 1 --branch $WHISPER_VERSION https://github.com/ggerganov/whisper.cpp.git
fi

cd whisper.cpp

# Build for Apple Silicon with Core ML and Metal support
echo "Building whisper.cpp with Core ML and Metal..."
make clean
WHISPER_COREML=1 WHISPER_METAL=1 CFLAGS="-O3 -DNDEBUG" make main

# Verify build
if [ ! -f "main" ]; then
  echo "Error: whisper.cpp build failed"
  exit 1
fi
echo "whisper.cpp binary built successfully"

# Download Large-v3-Turbo Q5_0 model if not cached
MODEL_NAME="large-v3-turbo-q5_0"
MODEL_FILE="ggml-${MODEL_NAME}.bin"

if [ ! -f "models/${MODEL_FILE}" ]; then
  echo "Downloading whisper ${MODEL_NAME} model..."
  # download-ggml-model.sh might not have this specifically in its list depending on version, 
  # but the script allows passing any model name if it exists on HF.
  bash ./models/download-ggml-model.sh "${MODEL_NAME}"
fi

# Verify model
if [ ! -f "models/${MODEL_FILE}" ]; then
  echo "Error: Failed to download whisper ${MODEL_NAME} model"
  # Try direct download if script fails
  # curl -L -o "models/${MODEL_FILE}" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${MODEL_FILE}"
  exit 1
fi

# Generate Core ML encoder for the model
echo "Generating Core ML encoder for ${MODEL_NAME}..."
# Ensure dependencies are met (coremltools, etc.) - user should have these or we'll find out
# Note: large-v3-turbo uses 'large-v3-turbo' as the base name for conversion
bash ./models/generate-coreml-model.sh "large-v3-turbo"

echo "whisper.cpp build complete"
echo "Binary: $(pwd)/main"
echo "Model: $(pwd)/models/${MODEL_FILE}"

# Copy to SalesCoach Resources
cd ..
echo "Copying binaries and models to SalesCoach/Resources..."
mkdir -p SalesCoach/Resources

cp whisper.cpp/main SalesCoach/Resources/whisper-cli
chmod +x SalesCoach/Resources/whisper-cli
cp "whisper.cpp/models/${MODEL_FILE}" SalesCoach/Resources/
cp -R "whisper.cpp/models/ggml-large-v3-turbo-encoder.mlmodelc" SalesCoach/Resources/

# Verify all files copied
echo "=== Verifying SalesCoach/Resources ==="
ls -la SalesCoach/Resources/

if [ ! -f "SalesCoach/Resources/whisper-cli" ]; then
  echo "Error: whisper-cli not copied"
  exit 1
fi

if [ ! -f "SalesCoach/Resources/${MODEL_FILE}" ]; then
  echo "Error: ${MODEL_FILE} not copied"
  exit 1
fi

if [ ! -d "SalesCoach/Resources/ggml-large-v3-turbo-encoder.mlmodelc" ]; then
  echo "Error: Core ML model folder not copied"
  exit 1
fi

echo "=== whisper.cpp setup complete ==="
echo "All resources copied to SalesCoach/Resources/"

