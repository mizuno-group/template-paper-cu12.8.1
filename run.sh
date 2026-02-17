#!/bin/bash
#SBATCH --job-name=Hello_test

#SBATCH --partition=batch
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --mem=16G

source ~/.bashrc
if [ ! -f testenv.sif ]; then
    apptainer build --fakeroot testenv.sif testenv.def
fi

TIMESTAMP=$(date +%y%m%d_%H%M)
OUT_DIR="results/${TIMESTAMP}_${SLURM_JOB_ID}"
mkdir -p "$OUT_DIR"

exec > >(tee -a "${OUT_DIR}/stdout.log")
exec 2> >(tee -a "${OUT_DIR}/stderr.log" >&2)

cp "$0" "$OUT_DIR/job_script.sh"
cp config.yaml "$OUT_DIR/config.yaml"
git rev-parse HEAD > "$OUT_DIR/git_commit.txt"
git diff > "$OUT_DIR/git_diff.patch"

ln -snf "$(realpath $OUT_DIR)" results/latest

apptainer exec --nv testenv.sif bash -c "
    python3 scripts/00_test.py"
