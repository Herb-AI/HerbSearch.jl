using Pkg
using Conda

Conda.pip_interop(true)
Conda.pip("install", "setuptools==65.5.0")
Conda.pip("install", "pip==21")
Conda.pip("install", "wheel==0.38.0")
Conda.pip("install", "git+https://github.com/eErr0Re/minerl@prog-synth")
Conda.pip("install", "pyglet==1.5")

ENV["PYTHON"] = Conda.PYTHONDIR * "/python3"
Pkg.build("PyCall")
