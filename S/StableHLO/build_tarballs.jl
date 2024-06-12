# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

const YGGDRASIL_DIR = "../.."
include(joinpath(YGGDRASIL_DIR, "fancy_toys.jl"))
include(joinpath(YGGDRASIL_DIR, "platforms", "llvm.jl"))

name = "StableHLO"
version = v"1.1.2"

sources = [
    GitSource("https://github.com/openxla/stablehlo.git", "14e2323f0ee3d308c1384fdb806dc6d0c98b16ca"),
]

llvm_versions = [v"17.0.6+0"]

script = raw"""
cd $WORKSPACE/srcdir/stablehlo

# need to run mlir-tblgen and mlir-pdll on the host
# rm ${bindir}/mlir-tblgen ${bindir}/mlir-pdll
# ln -s ${host_prefix}/bin/mlir-tblgen ${bindir}/mlir-tblgen
# ln -s ${host_prefix}/bin/mlir-pdll ${bindir}/mlir-pdll

# CMAKE_FLAGS=()
# CMAKE_FLAGS+=(-DCMAKE_INSTALL_PREFIX=${prefix})
# CMAKE_FLAGS+=(-DCMAKE_BUILD_TYPE=Release)
# CMAKE_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN})
# CMAKE_FLAGS+=(-DCMAKE_CROSSCOMPILING:BOOL=ON)

# CMAKE_FLAGS+=(-DLLVM_DIR=${prefix}/lib/cmake/llvm)
# CMAKE_FLAGS+=(-DLLVM_ENABLE_ASSERTIONS=OFF)
# CMAKE_FLAGS+=(-DLLVM_LINK_LLVM_DYLIB=ON)
# CMAKE_FLAGS+=(-DLLVM_ENABLE_LLD="OFF")

# CMAKE_FLAGS+=(-DMLIR_DIR=${prefix}/lib/cmake/mlir)

# # building shared libraries crashes on linking, so build static libraries and link them manually
# CMAKE_FLAGS+=(-DBUILD_SHARED_LIBS=OFF)

# cmake -B build -S . -GNinja ${CMAKE_FLAGS[@]}
# ninja -C build -j 1 all

# # NOTE no idea why they are not installed by default
# install -v build/bin/stablehlo-opt build/bin/stablehlo-translate build/bin/stablehlo-lsp-server ${bindir}

# # build shared library from static libraries
# cd build/lib
# for i in *.a; do
#     echo $i
#     ar x $i
# done
# c++ -shared -o libStablehlo.${dlext} -lLLVM -lMLIR *.cpp.o
# install -v libStablehlo.${dlext} ${libdir}

# generate Julia bindings of the HLO dialects
mkdir -p ${prefix}/share/stablehlo_jll/
mlir-jl-tblgen --generator jl-op-defs \
    --external \
    -o ${prefix}/share/stablehlo_jll/stablehlo.inc.jl \
    -I ${host_prefix}/include/ \
    -I stablehlo/ \
    stablehlo/dialect/StablehloOps.td

mlir-jl-tblgen --generator jl-op-defs \
    --external \
    -o ${prefix}/share/stablehlo_jll/chlo.inc.jl \
    -I ${host_prefix}/include/ \
    -I stablehlo/ \
    stablehlo/dialect/ChloOps.td

mlir-jl-tblgen --generator jl-op-defs \
    --external \
    -o ${prefix}/share/stablehlo_jll/vhlo.inc.jl \
    -I ${host_prefix}/include/ \
    -I stablehlo/ \
    stablehlo/dialect/VhloOps.td
"""

platforms = supported_platforms()
filter!(==(64) ∘ wordsize, platforms)
filter!(!=("powerpc64le") ∘ arch, platforms)
filter!(!Sys.iswindows, platforms)
platforms = expand_cxxstring_abis(platforms)

products = [
    # ExecutableProduct("stablehlo-opt", :stablehlo_opt),
    # ExecutableProduct("stablehlo-translate", :stablehlo_translate),
    # ExecutableProduct("stablehlo-lsp-server", :stablehlo_lsp_server),
    # LibraryProduct("libStablehlo", :libStablehlo),
    FileProduct("share/stablehlo_jll/stablehlo.inc.jl", :stablehlo_inc_jl),
    FileProduct("share/stablehlo_jll/chlo.inc.jl", :chlo_inc_jl),
    FileProduct("share/stablehlo_jll/vhlo.inc.jl", :vhlo_inc_jl),
]

augment_platform_block = """
    using Base.BinaryPlatforms
    $(LLVM.augment)
    function augment_platform!(platform::Platform)
        augment_llvm!(platform)
    end"""

builds = []
for llvm_version in llvm_versions

    dependencies = [
        # Dependency("MLIR_jll", llvm_version),
        # BuildDependency(PackageSpec(name="LLVM_full_jll", version=llvm_version)),
        HostBuildDependency(PackageSpec(name="MLIR_jll", version=llvm_version)),
        HostBuildDependency(PackageSpec(name="mlir_jl_tblgen_jll", version=v"0.0.8+0")),
    ]

    for platform in platforms
        augmented_platform = deepcopy(platform)
        llvm_assertions = false
        augmented_platform[LLVM.platform_name] = LLVM.platform(llvm_version, llvm_assertions)

        should_build_platform(triplet(augmented_platform)) || continue
        push!(builds, (; dependencies, platforms=[augmented_platform]))
    end
end

for (i, build) in enumerate(builds)
    build_tarballs(ARGS,
        name,
        version,
        sources,
        script,
        build.platforms,
        products,
        build.dependencies;
        julia_compat="1.10",
        preferred_gcc_version=v"9",
        preferred_llvm_version=v"17",
        augment_platform_block,
        lazy_artifacts=true)
end
