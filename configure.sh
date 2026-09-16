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
      -DPACE_PYTHON_EXEC="$(which python3)" \
      ../cmake 2>&1 | tee cmake.log

# PACE_PYTHON_EXEC is passed explicitly. ML-PACE.cmake locates TensorFlow by
# asking a Python interpreter where the package lives, and its own
# find_program(python3) picks the spack MODULE python, not the venv one, even
# with the venv active. That python has no tensorflow, so discovery returns
# nothing and CMake quietly downloads TF 2.18 and builds against that instead
# -- a different TensorFlow from the one loaded at run time.
#
# TF_LIB_FILE is deliberately NOT passed. Setting it takes a branch of
# ML-PACE.cmake that never sets TF_INCLUDE_PATH, so cppflow fails to find
# tensorflow/c/tf_tensor.h and the compile dies ~2000 objects in. The Python
# discovery branch sets the library AND the include path, and with the grace
# venv active it finds exactly the library we want anyway.
#
# Verify that rather than trust it: a TensorFlow picked up from somewhere else
# would build and then mismatch the one loaded at run time.
grep -i "TensorFlow library found at" cmake.log || {
    echo "FATAL: TensorFlow library was not found by CMake"; exit 1; }
grep -i "TensorFlow library found at" cmake.log | grep -q "$TF_DIR" || {
    echo "FATAL: CMake found a TensorFlow outside the grace venv ($TF_DIR):"
    grep -i "TensorFlow library found at" cmake.log; exit 1; }
[ -f "$TF_DIR/include/tensorflow/c/tf_tensor.h" ] || {
    echo "FATAL: no TF C headers at $TF_DIR/include"; exit 1; }
echo "=== configure OK ==="
