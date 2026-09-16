#!/bin/bash
source /apps/modules/system/init/bash
module purge
module load 000-all-spack-pkgs/1.1.1-alex
module load python/3.13.8-gcc11.5.0-apqbs3h
module load openmpi/5.0.8-gcc11.5.0-cuda12.9
source ~/venv/grace/bin/activate
export TF_USE_LEGACY_KERAS=1
cd ~/lammps/test_grace_q
M=$HOME/projects/lorem-q-work/experiments/razor-grace/seed/1/final_model_fixed
for q in -0.5 0.5; do
  echo "=== q=$q ==="
  ~/lammps/build/lmp -var Q $q -var MODEL $M -in in.grace 2>&1 | grep -A2 "^ *Step" | head -3
done
