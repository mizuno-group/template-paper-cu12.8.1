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
# 環境変数として.workspace_rcを宣言
source ../.workspace_rc
PROJECT_NAME=$(basename "$SLURM_SUBMIT_DIR")

# projectのディレクトリが計算ノード側にあるか確認して、なければ作成する
PROJECT_DIR="/scratch/$USER/$PROJECT_NAME"
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Creating project directory at $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
fi

# 必要なファイルを計算ノード側のプロジェクトディレクトリに転送する
rsync -av scripts src env.sif pyproject.toml uv.lock data* "$PROJECT_DIR/"

# データが圧縮されている場合は展開する
if [ -f "$PROJECT_DIR/data.tar.gz" ] && [ ! -d "$PROJECT_DIR/data" ]; then
    echo "Extracting data..."
    tar -xzf "$PROJECT_DIR/data.tar.gz" -C "$PROJECT_DIR/"
fi

cd "$PROJECT_DIR"

# .venvを作成
apptainer exec --nv "env.sif" \
    bash -c "uv sync"

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
# 実験の内容に応じて、00_test.pyの部分を適切なスクリプトに置き換える
apptainer exec --nv env.sif bash -c "uv run python scripts/00_test.py --out $OUT_DIR"

# 結果をCache領域に転送
rsync -av "$OUT_DIR" "$SLURM_SUBMIT_DIR/results/"

# データセットや出力だけを消し、.venv と .uv_cache は維持
find "$PROJECT_DIR" -maxdepth 1 ! -name '.venv' ! -name '.uv_cache' ! -name '.' -exec rm -rf {} +
