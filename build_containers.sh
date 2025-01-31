#!/bin/bash

# Exit on error
set -e

echo "Building Singularity containers..."

# Build PostgreSQL container
echo "Building PostgreSQL container..."
sudo singularity build postgres.sif singularity/postgres.def

# Build n8n container
echo "Building n8n container..."
sudo singularity build n8n.sif singularity/n8n.def

# Build Qdrant container
echo "Building Qdrant container..."
sudo singularity build qdrant.sif singularity/qdrant.def

# Build Ollama container
echo "Building Ollama container..."
sudo singularity build ollama.sif singularity/ollama.def

echo "All containers built successfully!" 