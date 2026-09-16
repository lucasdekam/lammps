#!/bin/bash
#SBATCH --job-name=lmp-grace-build
#SBATCH --output=build.out
#SBATCH --nodes 1
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 32
#SBATCH --partition=a100
#SBATCH --constraint=a100_80
#SBATCH --gpus-per-node 1
#SBATCH --time 02:00:00

# LAMMPS with the GRACE TensorFlow pair styles, built for A100 nodes.
#
# No Kokkos: the TF pair styles carry the charge conditioning, and the Kokkos
# ones read an exported .npz that the FiLM architecture would not survive
# anyway (export_kokkos rejects non-standard instruction graphs).
#
# EXTRA-FIX is in for fix temp/csvr, in case the CSVR thermostat is wanted
# later -- the LOREM arms use ASE Langevin and a matched thermostat keeps the
# comparison honest.
#
# TF_LIB_FILE points at the library the grace venv already ships, so CMake does
# not try to download its own and the runtime and build-time TensorFlow are the
# same one.

set -e
source /apps/modules/system/init/bash
module purge
module load 000-all-spack-pkgs/1.1.1-alex
module load python/3.13.8-gcc11.5.0-apqbs3h
module load cmake/3.31.9
module load cuda/12.8.1
module load openmpi/5.0.8-gcc11.5.0-cuda12.9
source ~/venv/grace/bin/activate

TF_DIR="$(python3 -c "import tensorflow, os; print(os.path.dirname(tensorflow.__file__))")"
echo "TensorFlow dir: $TF_DIR"
ls -la "$TF_DIR"/libtensorflow_cc.so* "$TF_DIR"/libtensorflow_framework.so*

cd ~/lammps/build
rm -rf CMakeCache.txt CMakeFiles

cmake -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_MPI=ON \
      -DPKG_ML-PACE=ON \
      -DPKG_MC=ON \
      -DPKG_EXTRA-FIX=ON \
      -DPKG_KSPACE=ON \
      -DPKG_MOLECULE=ON \
      -DPKG_RIGID=ON \
      -DTF_LIB_FILE="$TF_DIR/libtensorflow_cc.so.2" \
      ../cmake 2>&1 | tee cmake.log

grep -i "TensorFlow library is FOUND" cmake.log || {
    echo "FATAL: TensorFlow library was not found by CMake"; exit 1; }

cmake --build . -- -j 32 2>&1 | tail -40
echo "=== built ==="
ls -la lmp
./lmp -h 2>/dev/null | grep -iA2 "pair_style" | grep -i grace | head
