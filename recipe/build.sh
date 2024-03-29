#!/usr/bin/env bash
set -ex
if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
  export FF_OPTIONS="${FF_OPTIONS} --with-mpi=yes"
else
  export FF_OPTIONS="${FF_OPTIONS} --without-mpi"
fi

echo "**************** F R E E F E M  B U I L D  S T A R T S  H E R E ****************"

autoreconf -i
## Required to make linker look in correct prefix
export LIBRARY_PATH="${PREFIX}/lib"
export LD_LIBRARY_PATH="${PREFIX}/lib"

./configure --prefix=$PREFIX \
            --enable-optim \
            --enable-debug \
            ${FF_OPTIONS} \
            --with-arpack=${PREFIX}/lib/libarpack${SHLIB_EXT} \
            --disable-fortran

make -j $CPU_COUNT
make install
rm $PREFIX/lib/ff++/${PKG_VERSION}/lib/*.${SHLIB_EXT} || true # to avoid conda DSO errors
rm $PREFIX/lib/ff++/${PKG_VERSION}/lib/*.a || true # static libraries are not allowed
make check -j $CPU_COUNT check

echo "**************** F R E E F E M  B U I L D  E N D S  H E R E ****************"
