#!/bin/bash

CONTAINER_IMAGE="testenv.sif"

# uvのキャッシュディレクトリをホスト側に固定（高速化のため）
export UV_CACHE_DIR="$(pwd)/.uv_cache"
mkdir -p "$UV_CACHE_DIR"

echo "=== uv syncing (creating .venv) ==="

# apptainer exec でコンテナ内の uv を呼び出す
apptainer exec --nv --bind $(pwd):$(pwd) "$CONTAINER_IMAGE" \
    bash -c "cd $(pwd) && \
             uv venv .venv && \
             uv sync"

echo "=== Setup Complete ==="
echo "To activate the environment, run: source .venv/bin/activate"
