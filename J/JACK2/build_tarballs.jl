using BinaryBuilder

name = "JACK2"
version = v"1.9.22"

sources = [
    GitSource("https://github.com/jackaudio/jack2.git", "4f58969432339a250ce87fe855fb962c67d00ddb")
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/jack2

./waf configure --prefix=${prefix} --autostart=none
./waf build
./waf install
"""

platforms = supported_platforms()

products = [
]

# Dependencies that must be installed before this package can be built
dependencies = []

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6")
