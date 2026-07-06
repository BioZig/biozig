# setup.R is run before the tests
pkg_dir <- normalizePath("../..")

# Load shared libraries
lib_ext <- if (Sys.info()["sysname"] == "Darwin") ".dylib" else ".so"
biozig_lib <- normalizePath(file.path(pkg_dir, "../../..", "zig-out", "lib", paste0("libbiozig", lib_ext)))
dyn.load(biozig_lib, local = FALSE)

wrapper_lib <- normalizePath(file.path(pkg_dir, "src", "wrapper.so"))
dyn.load(wrapper_lib)

# Source the R files
source(file.path(pkg_dir, "R", "core.R"))
source(file.path(pkg_dir, "R", "molecular.R"))
