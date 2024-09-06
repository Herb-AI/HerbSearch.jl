"""
Dev environment setup script inspired by that of the `Flux.jl` package, which
can be found at:
https://github.com/FluxML/Flux.jl/blob/caa1ceef9cf59bd817b7bf5c94d0ffbec5a0f32c/dev/setup.jl
"""

# instantiate the environment
using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

# setup the custom git hook
using Git

# set the local hooks path
const git = Git.git()
run(`$git config --local core.hooksPath .githooks/`)

# set file permission for hook
Base.Filesystem.chmod(".githooks", 0o777; recursive = true)
