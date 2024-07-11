#!/bin/bash
BAK_DIR=$(pwd)
BAK_MODE=$FLOATZONE_MODE
set -e
unset FLOATZONE_MODE

#Check we loaded env.sh
if [ -z $FLOATZONE_C ]
then
  echo $FLOATZONE_C
  echo "Env variables not found!"
  exit 1
fi

#Checking if LLVM default is present
if [[ ! -f $DEFAULT_C ]]
then
  mkdir -p $DEFAULT_LLVM_BUILD
  cd $DEFAULT_LLVM_BUILD
  cmake -DLLVM_ENABLE_PROJECTS="clang;compiler-rt;openmp" -DCMAKE_CXX_FLAGS=-DDEFAULTCLANG -DCMAKE_BUILD_TYPE=Release -GNinja -DLLVM_PARALLEL_LINK_JOBS=1 -DLLVM_TARGETS_TO_BUILD="X86" -DCLANG_ENABLE_STATIC_ANALYZER=OFF -DCLANG_ENABLE_ARCMT=OFF $FLOATZONE_LLVM 
  ninja

  cp $DEFAULT_LLVM_BUILD/projects/openmp/runtime/src/omp.h $DEFAULT_LLVM_BUILD/lib/clang/14.0.6/include
fi

#Checking Floatzone LLVM is present and compiled
if [[ ! -f $FLOATZONE_C ]]
then
  #Doing the cmake of LLVM
  mkdir -p $FLOATZONE_LLVM_BUILD
  cd $FLOATZONE_LLVM_BUILD
  cmake -DLLVM_ENABLE_PROJECTS="clang;compiler-rt;openmp" -DCMAKE_BUILD_TYPE=Release -GNinja -DLLVM_PARALLEL_LINK_JOBS=1 -DLLVM_TARGETS_TO_BUILD="X86" -DCLANG_ENABLE_STATIC_ANALYZER=OFF -DCLANG_ENABLE_ARCMT=OFF $FLOATZONE_LLVM 
  ninja

  cp $FLOATZONE_LLVM_BUILD/projects/openmp/runtime/src/omp.h $FLOATZONE_LLVM_BUILD/lib/clang/14.0.6/include
fi

#Always compile LLVM
cd $FLOATZONE_LLVM_BUILD
ninja

# If after compilation we still do not have clang, abort
if [[ ! -f $FLOATZONE_C ]]
then
  echo "Missing clang, ABORT"
  exit -1
fi

# Check XED
if [[ ! -f $FLOATZONE_XED_LIB_SO ]]
then
  echo "Missing libxed.so, compiling it"
  cd $FLOATZONE_XED
  ./mfile.py --shared #--extra-flags=-fPIC

  if [[ ! -f $FLOATZONE_XED_LIB_SO ]]
  then
    echo "Missing libxed.so, ABORT"
    exit -1
  fi
fi

# AFLplusplus
if [[ ! -f $AFLPP ]]
then
    cd $AFLPP
    PATH_BAK=$PATH
    export PATH="$FLOATZONE_LLVM_BUILD/bin/:$PATH"
    unset FLOATZONE_MODE
    make clean
    make -j
    export PATH=$PATH_BAK
fi

#Always compile wrap.so
cd $WRAP_DIR
make
if [[ ! -f $FLOATZONE_LIBWRAP_SO ]]
then
  echo "Missing libwrap.so, ABORT"
  exit -1
fi

cd $BAK_DIR
export FLOATZONE_MODE=$BAK_MODE
