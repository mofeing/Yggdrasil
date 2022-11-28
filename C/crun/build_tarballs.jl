# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, BinaryBuilderBase, Pkg

name = "crun"
version = v"1.7.1"

# Collection of sources required to complete build
sources = [
    ArchiveSource("https://github.com/containers/crun/releases/download/$(version)/crun-$(version).tar.xz",
                  "bceade123d27ce31ab31bca14351e0cf4951e57b5b45de7a2dd3d512ef17912f")
]

# Bash recipe for building across all platforms
script = raw"""
cd crun-*
install_license COPYING

./autogen.sh
./configure --prefix=${prefix} --build=${MACHTYPE} --host=${target} \
            --enable-shared --enable-dynamic \
            --disable-seccomp --disable-systemd --disable-criu
# disabled components are because of missing JLLs
make -j${nproc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = filter!(Sys.islinux, supported_platforms())

# The products that we will ensure are always built
products = [
    ExecutableProduct("crun", :crun),
    LibraryProduct("libcrun", :libcrun)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("YAJL_jll"),
    Dependency("libcap_jll")
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.6", preferred_gcc_version = v"11")
