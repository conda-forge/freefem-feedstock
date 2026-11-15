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

./configure --prefix=$PREFIX \
            ${FF_OPTIONS} \
            --enable-summary \
            --enable-gmm \
            --enable-optim

# Unpack HPDDM once before the parallel build: under make -j, 3rdparty's install-hpddm runs
# concurrently and the two 'rm -rf hpddm-*; unzip' race (missing HPDDM_define.hpp)
if [[ -f 3rdparty/pkg/hpddm.zip ]]; then
  make -C 3rdparty include/hpddm/done.tag lib/WHERE.hpddm
fi
make -j $CPU_COUNT
make install
cp $PREFIX/lib/ff++/${PKG_VERSION}/lib/*${SHLIB_EXT} $PREFIX/lib
#rm $PREFIX/lib/ff++/${PKG_VERSION}/lib/*.${SHLIB_EXT} || true # to avoid conda DSO errors
rm $PREFIX/lib/ff++/${PKG_VERSION}/lib/*.a || true # static libraries are not allowed
make check -j $CPU_COUNT check

echo "**************** F R E E F E M  B U I L D  E N D S  H E R E ****************"
