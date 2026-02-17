#!/bin/bash
#SBATCH --partition=interactive
#SBATCH --time=01:00:00

rm -f testenv.sif

apptainer build --fakeroot testenv.sif testenv.def

if [ $? -eq 0 ]; then
    echo "Build successful!"
else
    echo "Build failed..."
    exit 1
fi
