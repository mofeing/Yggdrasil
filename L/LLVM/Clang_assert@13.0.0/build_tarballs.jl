name = "Clang"
llvm_full_version = v"13.0.0+2"
libllvm_version = v"13.0.0+2"


# Include common LLVM stuff
include("../common.jl")
build_tarballs(ARGS, configure_extraction(ARGS, llvm_full_version, name, libllvm_version; experimental_platforms=true, assert=true)...; skip_audit=true,  julia_compat="1.8")
