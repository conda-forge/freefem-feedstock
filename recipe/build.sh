#!/usr/bin/env bash
set -ex
if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
  export FF_OPTIONS="${FF_OPTIONS} --with-mpi=yes"
  # PETSc/SLEPc from $PREFIX (configure reads lib/petsc/conf/petscvariables and finds libslepc
  # next to it); HPDDM from the zip the recipe puts in 3rdparty/pkg (needed by PETSc plugins)
  export FF_OPTIONS="${FF_OPTIONS} --with-petsc=${PREFIX}/lib --enable-download_hpddm"
else
  export FF_OPTIONS="${FF_OPTIONS} --without-mpi"
fi

if [[ "${target_platform}" == *-64 ]]; then
  export FF_OPTIONS="${FF_OPTIONS} --enable-m64"
else
  export FF_OPTIONS="${FF_OPTIONS} --enable-m32"
fi

echo "**************** F R E E F E M  B U I L D  S T A R T S  H E R E ****************"

autoreconf -i
export FFLAGS=-fallow-argument-mismatch
## Required to make linker look in correct prefix
export LIBRARY_PATH="${PREFIX}/lib"
export LD_LIBRARY_PATH="${PREFIX}/lib"

# --enable-generic: without it configure adds -mavx2/-mavx/-msse4.2 from the *build* machine's
# /proc/cpuinfo, and the packages crash (Illegal instruction) on CPUs without AVX2
./configure --prefix=$PREFIX \
            ${FF_OPTIONS} \
            --enable-summary \
            --enable-gmm \
            --enable-optim \
            --enable-generic

# Unpack HPDDM once before the parallel build: under make -j, 3rdparty's install-hpddm runs
# concurrently and the two 'rm -rf hpddm-*; unzip' race (missing HPDDM_define.hpp)
if [[ -f 3rdparty/pkg/hpddm.zip ]]; then
  mkdir -p 3rdparty/include 3rdparty/lib
  make -C 3rdparty include/hpddm/done.tag lib/WHERE.hpddm
  test -f 3rdparty/include/hpddm/include/HPDDM_define.hpp
fi
make -j $CPU_COUNT
make install
cp $PREFIX/lib/ff++/${PKG_VERSION}/lib/*${SHLIB_EXT} $PREFIX/lib
#rm $PREFIX/lib/ff++/${PKG_VERSION}/lib/*.${SHLIB_EXT} || true # to avoid conda DSO errors
rm $PREFIX/lib/ff++/${PKG_VERSION}/lib/*.a || true # static libraries are not allowed
if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
  # MPI examples run as ff-mpirun -np 4 under a 60 s CPU ulimit (bin/test-driver-ff). Running
  # them in parallel oversubscribes the runner, MPI busy-polling burns CPU time, and tests get
  # killed (seen with mpich on ffddm/natural_convection.edp), so run them one at a time
  CHECK_JOBS=1
  # MPICH busy-polls, so a rank's CPU time grows with wall time; ffddm/natural_convection.edp got
  # killed at the default 60 s while still converging
  export FF_TEST_CPU_LIMIT=300 FF_TEST_MPIEXEC_TIMEOUT=300
else
  CHECK_JOBS=$CPU_COUNT
fi
if ! make check -j $CHECK_JOBS; then
  # CI only shows the summary; print the end of each failing test's log
  for trs in $(grep -l -E '^:test-result: (FAIL|ERROR)' examples/*/*.trs); do
    echo "======== ${trs%.trs}.log"
    tail -40 "${trs%.trs}.log"
  done
  exit 1
fi

echo "**************** F R E E F E M  B U I L D  E N D S  H E R E ****************"
