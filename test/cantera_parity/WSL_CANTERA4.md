# User-run WSL reference environment: Cantera 4.0.0a2

For the completed setup, observed versions, and troubleshooting lessons in
Chinese, see [WSL 配置经验记录](WSL_CANTERA4_NOTES_zh.md).

This is the original staged setup handoff, not an installation script. Initial
installation and compilation were completed by the user. Subsequent authorized
agent reference/regression runs are retained in the
[batch verification record](verification/agent_batch_2026-10-29.md).
When setting up another environment, review each stage before proceeding. Do
not change the pinned version or numerical tolerances to bypass a failure.

The frozen source is
`726522be4e2a13454d8415b7ef799d621f665cf3`. The recipe below is for Ubuntu
24.04 or newer in WSL, Python 3.12–3.14, and GCC >=13.2. If stage 1 shows a
different distribution or older tools, decide the adjustment together first.
Keep the source and virtual environment in WSL's Linux filesystem; only the
small reference record is shared with the Windows Arrhenius checkout.

Upstream instructions and requirements used to prepare this handoff:

- [Dependencies at the fixed commit](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/doc/sphinx/develop/compiling/dependencies.md)
- [Ubuntu build requirements](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/doc/sphinx/develop/compiling/compilation-reqs.md)
- [Configure, build, and install](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/doc/sphinx/develop/compiling/configure-build.md)
- [Version constraints and options in SConstruct](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/SConstruct)

## 1. Inventory only — start here

In **Windows PowerShell**:

```powershell
wsl --list --verbose
```

Share this output first. It tells us whether WSL has an installed Linux
distribution and which one to open. Do not install a new distribution or
change the default until this is understood.

Then, inside the selected **WSL Bash** terminal:

```bash
cat /etc/os-release
python3 --version
command -v g++
command -v scons
printf 'Virtual environment: %s\n' "${VIRTUAL_ENV:-none}"
```

If `g++` exists, also run `g++ --version`. A missing command here is an
inventory finding, not a solver failure. Preserve the output as the record
of what can or cannot be reused. Do not assume a 4.0 environment is absent
merely because the Windows ForgeKinetic environment contains 3.2.0.

## 2. Install build prerequisites — after stage 1 review

For the Ubuntu route described above:

```bash
sudo apt update
sudo apt install build-essential git python3-dev python3-venv pkg-config
```

The fixed source expects Boost >=1.83; Ubuntu 24.04 provides it through:

```bash
sudo apt install libboost-dev
```

The build below disables HDF5 and Fortran and uses the source revision's
bundled SUNDIALS, Eigen, fmt, and yaml-cpp. The default build still generates
CLib interface code even when HTML documentation is disabled. This requires
Doxygen >=1.13 and the Python package Jinja2; see the pinned
[CLib build rule](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/interfaces/clib/SConscript).
Prepare both in stage 3. No separate system Cantera package is needed.

## 3. Manage the separate Python environment with uv

Use uv to create the environment and install its Python build dependencies.
Cantera itself is still built from the fixed source with SCons in stages 4–5.
The [uv environment interface](https://docs.astral.sh/uv/pip/environments/)
also supports virtual environments created with `python -m venv`, so an
environment already created in this handoff can be reused without recreating it.

First check uv inside **WSL**, not Windows:

```bash
command -v uv
uv --version
```

If it is absent, install it using the
[official Linux installer](https://docs.astral.sh/uv/getting-started/installation/),
then review the output before continuing:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source "$HOME/.local/bin/env"
uv --version
```

First check that these dedicated destinations do not contain existing work:

```bash
ls -ld "$HOME/.venvs/cantera-726522be" "$HOME/src/cantera-726522be"
```

Missing paths are expected for a new setup. If either already exists, inspect
it together before reusing it. Do not delete or overwrite it. In particular,
skip `uv venv` when reusing the environment created earlier in this handoff.
For a new environment, select Ubuntu's Python explicitly so its interpreter
matches the installed `python3-dev` headers:

```bash
mkdir -p "$HOME/.venvs" "$HOME/src"
uv venv --python /usr/bin/python3 "$HOME/.venvs/cantera-726522be"
source "$HOME/.venvs/cantera-726522be/bin/activate"
export PATH="$HOME/.local/bin:$HOME/.local/opt/doxygen-1.18.0/bin:$PATH"
```

Set PATH after activation. Re-sourcing an activation script can restore a
previous PATH and remove directories added just before activation. If `uv`
is not found but `"$HOME/.local/bin/uv" --version` works, fix this ordering
rather than reinstalling uv. Repeat the activation-then-export sequence in
each new terminal used for this handoff.

After activating the new or reused environment, install the build dependencies:

```bash
uv pip install --python "$VIRTUAL_ENV/bin/python" pip 'scons>=4.5,<5' 'Cython>=3.0.8,!=3.1.2,<4' 'numpy>=1.26.4,<3' 'ruamel.yaml>=0.17.21,<1' 'Jinja2>=2.10' setuptools wheel packaging typing_extensions pytest
```

Install `pip` explicitly as well: the Cantera Python build/install process
requires it, and a uv-created environment need not contain it initially.

These constraints come from the fixed source's requirements. They are not a
fully locked build environment; record the resolved versions before building:

```bash
python --version
g++ --version
uv pip freeze --python "$VIRTUAL_ENV/bin/python"
```

### Doxygen for the default interface-code generation

Check `doxygen --version` before building. The pinned Cantera requirements
specify >=1.13, so a distribution's older Doxygen package is insufficient.
For WSL x86_64, the [official Linux binary](https://www.doxygen.nl/download.html)
provides Doxygen 1.18.0 and publishes the SHA-256 below. Install it in a dedicated
user directory (inspect that directory first if it already exists):

```bash
mkdir -p "$HOME/.local/opt/doxygen-1.18.0"
curl -fL https://www.doxygen.nl/files/doxygen-1.18.0.linux.bin.tar.gz -o "$HOME/.local/opt/doxygen-1.18.0/archive.tar.gz"
printf '%s  %s\n' '14fa81bdc34171edb5f1f02b1d60e74802f0439b77fa44e592565d517d72df90' "$HOME/.local/opt/doxygen-1.18.0/archive.tar.gz" | sha256sum -c -
```

Continue only after the checksum reports `OK`:

```bash
tar -xzf "$HOME/.local/opt/doxygen-1.18.0/archive.tar.gz" -C "$HOME/.local/opt/doxygen-1.18.0" --strip-components=1
export PATH="$HOME/.local/opt/doxygen-1.18.0/bin:$PATH"
doxygen --version
```

Review the version output before building; keep this PATH setting active in
the terminal used for the build/install. In a new terminal, repeat the export.
If a previous build stopped with `doxygen: not found`, also install Jinja2 in
the active environment:

```bash
uv pip install --python "$VIRTUAL_ENV/bin/python" 'Jinja2>=2.10'
```

Then rerun the original stage 5 build command. SCons can reuse completed
targets. Do not change the source revision or numerical settings for this
missing-tool failure. This binary recipe has not been executed by the agent;
its checksum and version are user-run gates before retrying the build.

## 4. Check out the exact source

Still in WSL with the virtual environment active:

```bash
git clone --filter=blob:none --no-checkout https://github.com/Cantera/cantera.git "$HOME/src/cantera-726522be"
cd "$HOME/src/cantera-726522be"
git checkout --detach 726522be4e2a13454d8415b7ef799d621f665cf3
git submodule update --init --recursive
git rev-parse HEAD
git status --short
```

Verify the exact SHA and clean tracked source before continuing. `CT_GIT_COMMIT`
can override the version embedded by SCons; do not set it for this build.

## 5. Build, then install into the separate environment

Use two build jobs initially. The command is deliberately not a `test` target;
running solver tests remains a separate user decision.

```bash
env -u CT_GIT_COMMIT "$VIRTUAL_ENV/bin/scons" build -j2 python_package=y python_cmd="$VIRTUAL_ENV/bin/python" prefix="$VIRTUAL_ENV" python_prefix="$VIRTUAL_ENV" f90_interface=n hdf_support=n system_sundials=n system_eigen=n system_fmt=n system_yamlcpp=n
```

Review the build output before installation. A compiler, download, or missing
dependency failure should be diagnosed at this stage, without changing the
pinned source. SCons retains these options in its local `cantera.conf`.

```bash
env -u CT_GIT_COMMIT "$VIRTUAL_ENV/bin/scons" install
```

No `sudo` is needed for installation into the user-owned virtual environment.

## 6. Environment gate — no reactor solve

Set paths for the Windows checkout as seen from WSL and the Linux source:

```bash
ARRHENIUS_REPO=/mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl
CT4_SOURCE="$HOME/src/cantera-726522be"
python "$ARRHENIUS_REPO/test/cantera_parity/reactor_reference.py" --source-dir "$CT4_SOURCE" --check-environment
```

Review the JSON output together. It must report version `4.0.0a2`, the correct
embedded commit (possibly abbreviated), clean source at the full SHA, the
actual Python/module/extension paths, and the matching mechanism digest.
`environment_checked_only` means no reactor was constructed or solved.

## 7. Reference solve — only after the gate is accepted

```bash
python "$ARRHENIUS_REPO/test/cantera_parity/reactor_reference.py" --source-dir "$CT4_SOURCE" --output "$ARRHENIUS_REPO/test/cantera_parity/local-results/reactor-disable-chemistry.cantera.json"
```

The script advances to 11 seconds of physical time and checks the upstream
temperature/composition assertions. It writes a new record only after they
pass and refuses to overwrite an existing record. Choose a fresh output name
for a repeat run. `reference_passed_native_not_verified` explicitly leaves
the Julia verification pending.

Next, use the Julia preparation and single-test commands in [README.md](README.md).
After both outputs have been reviewed, the user decides whether the coverage
entry can be changed to verified. Until then it stays pending.
