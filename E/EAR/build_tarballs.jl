using BinaryBuilder

name = "EAR"
version = v"4.3.1"

sources = [
    GitSource("https://gitlab.bsc.es/ear_team/ear", "ad84e84c353475b935db703f44c0b313e4406243")
]

script = raw"""
cd $WORKSPACE/srcdir/ear

autoreconf -i
./configure --prefix=${prefix} --build=${MACHTYPE} --host=${target}
make -j${nproc}
make install
"""

platforms = supported_platforms(; exclude=p -> Sys.iswindows(p) || Sys.isfreebsd(p) || Sys.isapple(p), experimental=true)

products = Product[]

dependencies = Dependency[]

build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6")
