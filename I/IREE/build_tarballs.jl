# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

const YGGDRASIL_DIR = "../.."
include(joinpath(YGGDRASIL_DIR, "fancy_toys.jl"))
include(joinpath(YGGDRASIL_DIR, "platforms", "llvm.jl"))

name = "IREE"
version = v"0.0.820" # corresponds to tag `candidate-20240304.820`

sources = [
    GitSource("https://github.com/openxla/iree.git", "eda28bf01d10d13f86df9018cb1f35a2dcb1cadc"),
]

llvm_versions = [v"17.0.6+0"]

script = raw"""
cd $WORKSPACE/srcdir/iree

# skip fetching unused submodules
git \
    -c submodule."third_party/llvm-project".update=none \
    -c submodule."third_party/torch-mlir".update=none \
    -c submodule."third_party/pybind11".update=none \
    -c submodule."third_party/tracy".update=none \
    -c submodule."third_party/webgpu-headers".update=none \
    submodule update --init --recursive

# need to run mlir-tblgen and mlir-pdll on the host
# rm ${bindir}/mlir-tblgen ${bindir}/mlir-pdll
# ln -s ${host_prefix}/bin/mlir-tblgen ${bindir}/mlir-tblgen
# ln -s ${host_prefix}/bin/mlir-pdll ${bindir}/mlir-pdll

CMAKE_FLAGS=()
CMAKE_FLAGS+=(-DCMAKE_INSTALL_PREFIX=${prefix})
CMAKE_FLAGS+=(-DCMAKE_BUILD_TYPE=Release)
CMAKE_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN})
CMAKE_FLAGS+=(-DCMAKE_CROSSCOMPILING:BOOL=ON)

CMAKE_FLAGS+=(-DIREE_ERROR_ON_MISSING_SUBMODULES=OFF)
CMAKE_FLAGS+=(-DIREE_BUILD_COMPILER=ON)
CMAKE_FLAGS+=(-DIREE_BUILD_TESTS=OFF)
CMAKE_FLAGS+=(-DIREE_BUILD_DOCS=OFF)
CMAKE_FLAGS+=(-DIREE_BUILD_SAMPLES=OFF)
CMAKE_FLAGS+=(-DIREE_BUILD_PYTHON_BINDINGS=OFF)
CMAKE_FLAGS+=(-DIREE_BUILD_TRACY=OFF)
CMAKE_FLAGS+=(-DIREE_BUILD_BUNDLED_LLVM=OFF)
CMAKE_FLAGS+=(-DIREE_BUILD_BINDINGS_TFLITE=OFF)
CMAKE_FLAGS+=(-DIREE_BUILD_BINDINGS_TFLITE_JAVA=OFF)
CMAKE_FLAGS+=(-DIREE_TARGET_BACKEND_LLVM_CPU=ON)

# disable for now
CMAKE_FLAGS+=(-DIREE_CUDA_AVAILABLE=OFF)

# input MLIR dialects
CMAKE_FLAGS+=(-DIREE_INPUT_STABLEHLO=ON)
CMAKE_FLAGS+=(-DIREE_INPUT_TORCH=OFF)
CMAKE_FLAGS+=(-DIREE_INPUT_TOSA=ON)

CMAKE_FLAGS+=(-DBUILD_SHARED_LIBS=ON)

CMAKE_FLAGS+=(-DLLVM_DIR=${prefix}/lib/cmake/llvm)
CMAKE_FLAGS+=(-DLLVM_ENABLE_ASSERTIONS=OFF)
CMAKE_FLAGS+=(-DLLVM_LINK_LLVM_DYLIB=ON)
CMAKE_FLAGS+=(-DLLVM_ENABLE_LLD="OFF")
CMAKE_FLAGS+=(-DLLVM_EXTERNAL_LIT=${prefix}/tools/lit/lit.py)

CMAKE_FLAGS+=(-DMLIR_DIR=${prefix}/lib/cmake/mlir)

cmake -B build -S . -GNinja ${CMAKE_FLAGS[@]}
ninja -C build -j 1 all
"""

platforms = supported_platforms()
filter!(==(64) ∘ wordsize, platforms)
filter!(!=("powerpc64le") ∘ arch, platforms)
filter!(!Sys.iswindows, platforms)
platforms = expand_cxxstring_abis(platforms)

products = Product[
    ExecutableProduct("iree-run-module", :iree_run_module)
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
        Dependency("MLIR_jll", llvm_version),
        BuildDependency(PackageSpec(name="LLVM_full_jll", version=llvm_version)),
        HostBuildDependency(PackageSpec(name="MLIR_jll", version=llvm_version)),
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
        augment_platform_block,
        lazy_artifacts=true)
end
