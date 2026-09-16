#!/bin/bash
# CMake configure for LAMMPS + GRACE. RUN ON THE LOGIN NODE.
#
# Compute nodes on alex have no outbound network, and ML-PACE.cmake downloads
# three things at configure time: the PACE evaluator library, cppflow, and
# (unless TF_LIB_FILE is given) TensorFlow itself. Configure here, compile in
# the job -- configure is seconds of CPU, so it costs the login node nothing.
set -e
source /apps/modules/system/init/bash
module purge
module load 000-all-spack-pkgs/1.1.1-alex
module load python/3.13.8-gcc11.5.0-apqbs3h
module load cmake/3.31.9
module load openmpi/5.0.8-gcc11.5.0-cuda12.9
source ~/venv/grace/bin/activate

TF_DIR="$(python3 -c "import tensorflow, os; print(os.path.dirname(tensorflow.__file__))")"
echo "TensorFlow dir: $TF_DIR"

cd ~/lammps/build
rm -rf CMakeCache.txt CMakeFiles

cmake -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_MPI=ON \
      -DPKG_ML-PACE=ON \
      -DPKG_MC=ON \
      -DPKG_EXTRA-FIX=ON \
      -DPKG_MOLECULE=ON \
      -DPKG_RIGID=ON \
      -DTF_LIB_FILE="$TF_DIR/libtensorflow_cc.so.2" \
      ../cmake 2>&1 | tee cmake.log

grep -i "TensorFlow library found at" cmake.log || {
    echo "FATAL: TensorFlow library was not found by CMake"; exit 1; }
echo "=== configure OK ==="
