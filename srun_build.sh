#!/bin/bash
#SBATCH --job-name=lmp-grace-build
#SBATCH --output=build.out
#SBATCH --nodes 1
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 16
#SBATCH --partition=a100
#SBATCH --constraint=a100_80
#SBATCH --gpus-per-node 1
#SBATCH --time 02:00:00

# Compile only. `configure.sh` must have been run on the LOGIN node first:
# compute nodes here have no outbound network, and CMake configure downloads
# the PACE evaluator library and cppflow.
#
# No Kokkos: the TF pair styles carry the charge conditioning, and the Kokkos
# ones read an exported .npz that export_kokkos would reject for a FiLM model.
#
# EXTRA-FIX is in for fix temp/csvr, in case the CSVR thermostat is wanted
# later.

set -e
source /apps/modules/system/init/bash
module purge
module load 000-all-spack-pkgs/1.1.1-alex
module load python/3.13.8-gcc11.5.0-apqbs3h
module load cmake/3.31.9
module load openmpi/5.0.8-gcc11.5.0-cuda12.9
source ~/venv/grace/bin/activate

cd ~/lammps/build
[ -f CMakeCache.txt ] || { echo "FATAL: not configured -- run configure.sh on the login node"; exit 1; }

cmake --build . -- -j 16
echo "=== built ==="
ls -la lmp
