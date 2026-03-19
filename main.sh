#!/bin/bash
#SBATCH --job-name=Hello_test
#SBATCH --partition=large-creator
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --mem=16G
#SBATCH --output=test_output/test_%J.log
#SBATCH --error=test_output/test_%J.err

set -euo pipefail

# Scrach領域を利用する
# 環境変数として.bashrcを宣言
# source ~/.bashrc
CONTAINER_IMAGE="/mnt/HDD/$USER/env.sif"

# .sifファイルをコピーしておく

# sifがあるかどうかを確認、なければエラーを出す
if [ ! -f $CONTAINER_IMAGE ]; then
    cp env.sif $CONTAINER_IMAGE
fi

# projectのディレクトリがあるか確認して、なければ作成する
PROJECT_NAME=$(basename "$SLURM_SUBMIT_DIR")
PROJECT_DIR="/mnt/HDD/$USER/$PROJECT_NAME"
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Creating project directory at $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
fi

# .venvを作成
cp pyproject.toml "$PROJECT_DIR/"
if [ -f uv.lock ]; then
    cp uv.lock "$PROJECT_DIR/"
fi

apptainer exec --nv "$CONTAINER_IMAGE" \
    bash -c "uv venv $PROJECT_DIR/.venv --clear && \
             uv sync"
export UV_PROJECT_ENVIRONMENT="$PROJECT_DIR/.venv"

# ログなどの出力設定
TIMESTAMP=$(date +%y%m%d_%H%M)
OUT_DIR="$PROJECT_DIR/outputs/${TIMESTAMP}_${SLURM_JOB_ID}"

# 結果出力用のディレクトリを作成
mkdir -p "$OUT_DIR"

# 標準出力、エラー出力のファイル
exec > >(tee -a "${OUT_DIR}/stdout.log")
exec 2> >(tee -a "${OUT_DIR}/stderr.log" >&2)

# 実行スクリプト、実行した際のgitコミット、そこからの差分を記録

cp "$0" "$OUT_DIR/job_script.sh"
git rev-parse HEAD > "$OUT_DIR/git_commit.txt"
git diff > "$OUT_DIR/git_diff.patch"

# 最新の結果を表示するlatest下のリンク作成
ln -snf "$(realpath $OUT_DIR)" "$PROJECT_DIR/latest"

# コード実行
apptainer exec --nv $CONTAINER_IMAGE bash -c "uv run python scripts/00_test.py"

rsync -av "$OUT_DIR" "results/"
