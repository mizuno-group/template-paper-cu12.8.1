#!/bin/bash
#SBATCH --job-name=Hello_test
#SBATCH --partition=large-creator
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:1
#SBATCH --mem=120000
#SBATCH --output=output/test_%J.log
#SBATCH --error=output/test_%J.err

cleanup() {
    # 最後に必ず実行される処理
    echo "Job process finished. Starting cleanup..."
    cd "$SLURM_SUBMIT_DIR"

    if [ -d "$PROJECT_DIR" ]; then
        # 結果の回収
        echo "Transferring results back to submit directory..."
        mkdir -p "$SLURM_SUBMIT_DIR/results"
        # outputs と latest を回収
        rsync -av --include="$OUT_DIR/**" --include="latest" --exclude="*" "$PROJECT_DIR/" "$SLURM_SUBMIT_DIR/"
        
        # 前処理結果(data/processed)があれば回収
        if [ -d "$PROJECT_DIR/data/preprocessed" ]; then
            rsync -av "$PROJECT_DIR/data/preprocessed/" "$SLURM_SUBMIT_DIR/data/preprocessed/"
        fi

        # uv.lock の更新チェック
        if [ -f "$PROJECT_DIR/uv.lock" ] && ! diff -q "$PROJECT_DIR/uv.lock" "$SLURM_SUBMIT_DIR/uv.lock" > /dev/null 2>&1; then
            cp "$PROJECT_DIR/uv.lock" "$SLURM_SUBMIT_DIR/uv.lock"
        fi

        # Scratchの掃除
        # .venv と .uv_cache 以外を削除
        echo "Cleaning up scratch directory..."
        find "$PROJECT_DIR" -maxdepth 1 ! -name '.venv' ! -name '.uv_cache' ! -name "$(basename "$PROJECT_DIR")" -exec rm -rf {} +
        echo "Cleanup completed."
    fi
}

# 異常終了時も正常終了時も cleanup を呼ぶ
trap cleanup EXIT INT TERM

# --- 実行フェーズ ---

set -euo pipefail
source ../.workspace_rc
PROJECT_NAME=$(basename "$SLURM_SUBMIT_DIR")
PROJECT_DIR="/scratch/$USER/$PROJECT_NAME"

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

# sifファイルがあるか確認し、なければ作成する
if [ -f "$SLURM_SUBMIT_DIR/.env/env.sif" ]; then
    echo "Transferring env.sif to project directory..."
    cp "$SLURM_SUBMIT_DIR/.env/env.sif" "$PROJECT_DIR/"
else
    apptainer build --nv "$SLURM_SUBMIT_DIR/.env/env.sif" "$SLURM_SUBMIT_DIR/.env/env.def"
    cp "$SLURM_SUBMIT_DIR/.env/env.sif" "$PROJECT_DIR/"
fi

# 必要なファイルを計算ノード側のプロジェクトディレクトリに転送する
rsync -av scripts src pyproject.toml data* uv.lock .git .env "$PROJECT_DIR/"


# データが圧縮されている場合は展開する
if [ -f "$PROJECT_DIR/data.tar.gz" ] && [ ! -d "$PROJECT_DIR/data" ]; then
    echo "Extracting data..."
    tar -xzf "$PROJECT_DIR/data.tar.gz" -C "$PROJECT_DIR/"
fi

cd "$PROJECT_DIR"

# .venvを作成
apptainer exec --nv "$PROJECT_DIR/.env/env.sif" \
    bash -c "uv sync"

export UV_PROJECT_ENVIRONMENT="$PROJECT_DIR/.venv"

# ログなどの出力設定
TIMESTAMP=$(date +%y%m%d_%H%M)
OUT_DIR="$PROJECT_DIR/outputs/${TIMESTAMP}_${SLURM_JOB_ID}"

# 結果出力用のディレクトリを作成
mkdir -p "$OUT_DIR"

# 標準出力、エラー出力のファイル
# test_output内にも出力される、これはわかりやすく実行と紐づけるためなのでどちらかを消してもよいが実行途中にエラーになるとこちらは手元に戻らないので消すならこっち
# もしくは出力先をこっちにすれば解決するがoutputディレクトリの同期が大変になるか？
exec > >(tee -a "${OUT_DIR}/stdout.log")
exec 2> >(tee -a "${OUT_DIR}/stderr.log" >&2)

# 実行スクリプト、実行した際のgitコミット、そこからの差分を記録
cp "$0" "$OUT_DIR/job_script.sh"
git rev-parse HEAD > "$OUT_DIR/git_commit.txt"
git diff > "$OUT_DIR/git_diff.patch"

# 最新の結果を表示するlatest下のリンク作成
ln -snf "$(realpath "$OUT_DIR")" "$PROJECT_DIR/latest"

# メイン実行
apptainer exec --nv --bind /workspace/filesrv01/honzawa/wsi_preprocess/data:/data "$PROJECT_DIR/.env/env.sif" bash -c "uv run python scripts/00_test.py"