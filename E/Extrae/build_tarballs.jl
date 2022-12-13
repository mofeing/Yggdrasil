#!/usr/bin/env julia
using BinaryBuilder, Pkg

name = "Extrae"
version = v"4.0.2" # NOTE this is version 4.0.2rc1. its release candidate, but we needed a patch for Binutils 2.39
sources = [
    GitSource("https://github.com/bsc-performance-tools/extrae", "5eb2a8ad56aca035b1e13b021a944143e59e6b4a"),
    DirectorySource("$(@__DIR__)/bundled"),
]

script = raw"""
cd ${WORKSPACE}/srcdir/extrae

atomic_patch -p1 ${WORKSPACE}/srcdir/patches/0001-autoconf-replace-pointer-size-check-by-AC_CHECK_SIZE.patch
atomic_patch -p1 ${WORKSPACE}/srcdir/patches/0002-autoconf-use-simpler-endianiness-check.patch

if [ $(uname -m) == "aarch64" ]; then
    export ENABLE_ARM64=1
fi

autoreconf -fvi
./configure \
    --prefix=${prefix} \
    --build=${MACHTYPE} \
    --host=${target} \
    ${ENABLE_ARM64:+--enable-arm64} \
    --without-dyninst \
    --disable-nanos \
    --disable-smpss \
    --without-mpi \
    --with-binutils=$prefix \
    --with-unwind=$prefix \
    --with-xml-prefix=$prefix \
    --with-papi=$prefix

make -j${nproc}
make install
"""

platforms = [
    Platform("x86_64", "linux"; libc="gnu"),
    Platform("powerpc64le", "linux"; libc="gnu"),
    Platform("aarch64", "linux"; libc="gnu"),
]

products = [
    LibraryProduct("libseqtrace", :libseqtrace),
    LibraryProduct("libpttrace", :libpttrace),
    ExecutableProduct("extrae-cmd", :extrae_cmd),
    ExecutableProduct("extrae-header", :extrae_header),
    ExecutableProduct("extrae-loader", :extrae_loader),
]

dependencies = [
    Dependency("Binutils_jll"),
    Dependency("LibUnwind_jll"),
    Dependency("PAPI_jll"),
    Dependency("XML2_jll"),
]

build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6")
