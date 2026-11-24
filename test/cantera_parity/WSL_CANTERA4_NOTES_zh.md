# WSL 中构建 Cantera 4.0 的经验记录

记录日期：2026-10-29。

为 ForgeKinetic issue #5 准备独立的 Cantera 参考环境，最终在 WSL 2 的 Ubuntu 24.04 中完成了固定源码的编译、安装和环境核对。Python 环境与依赖由 uv 管理，Cantera 本体通过 SCons 从源码构建。原有 Windows 环境中的 Cantera 3.2.0 继续保留。

最容易反复卡住的环节是终端 PATH 和构建工具依赖。正确做法是先激活虚拟环境，再补 uv、Doxygen 的路径，并在编译前确认接口代码生成所需的 Doxygen 和 Jinja2 已就绪。

这份记录用于复用本次配置方法和排查思路。逐阶段执行说明见 [WSL 配置指南](WSL_CANTERA4.md)，后续单项测试结果见 [独立验证记录](verification/disable_chemistry_2026-10-29.md)。

## 配置结果

| 项目 | 本次环境 |
|---|---|
| Linux 发行版 | Ubuntu 24.04 LTS，WSL 2 |
| Linux 用户 | `subspace` |
| Python | 3.12.3 |
| GCC | 13.3.0 |
| Git | 2.43.0 |
| Boost 开发包 | `1.83.0.1ubuntu2` |
| uv | `0.13.6`，Linux x86_64 |
| Doxygen | 1.18.0 官方 Linux 二进制包，下载摘要校验通过 |
| Jinja2 | 3.1.6，依赖 MarkupSafe 3.0.4 |
| Cantera | 4.0.0a2 |
| SUNDIALS | 7.5.0，使用 Cantera 固定子模块 |

Cantera 源码固定在：

```text
726522be4e2a13454d8415b7ef799d621f665cf3
```

环境目录分工如下。`$HOME` 在本次 WSL 中为 `/home/subspace`；下面的目录彼此独立。

| 用途 | 路径 |
|---|---|
| Cantera Python 环境及安装位置 | `$HOME/.venvs/cantera-726522be` |
| Cantera 源码及构建产物 | `$HOME/src/cantera-726522be` |
| uv 可执行文件 | `$HOME/.local/bin/uv` |
| Doxygen 安装目录 | `$HOME/.local/opt/doxygen-1.18.0` |
| Windows 项目在 WSL 中的路径 | `/mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl` |

源码、构建和 Python 环境放在 WSL 的 Linux 文件系统；参考脚本读取 Windows 项目中的固定机制，并把结果写回项目目录。整个过程中，用户执行安装、构建、环境核对和测试，助手提供代码、命令及输出分析。

## 新终端中恢复环境

已有环境配置成功后，重开 WSL 不需要重新安装。按下面的顺序恢复即可：

```bash
source "$HOME/.venvs/cantera-726522be/bin/activate"
export PATH="$HOME/.local/bin:$HOME/.local/opt/doxygen-1.18.0/bin:$PATH"
cd "$HOME/src/cantera-726522be"

uv --version
which python
doxygen --version
```

`which python` 应指向虚拟环境的 `bin/python`。这段 PATH 设置只作用于当前终端；本次没有把它写进 `.bashrc`。如果再次激活环境，应在激活之后重新设置 PATH。

## 从现有 WSL 到编译完成

### 确认系统和编译工具

在 Windows PowerShell 中检查并启动已有发行版：

```powershell
wsl --list --verbose
wsl -d Ubuntu-24.04
```

最初输出中的 `Stopped` 表示发行版未运行。进入 WSL 后，确认系统、Python 和编译器：

```bash
cat /etc/os-release
python3 --version
command -v g++
g++ --version
```

本次已有 Python 3.12.3，但缺少 C++ 编译器。随后安装系统依赖：

```bash
sudo apt update
sudo apt install build-essential git python3-dev python3-venv pkg-config libboost-dev
```

安装后，用 `g++ --version`、`git --version` 和以下命令确认版本：

```bash
dpkg-query -W libboost-dev python3-dev python3-venv
```

`sudo` 使用 Ubuntu 用户密码，输入时不回显字符。密码问题应先独立解决，再继续依赖安装。

### 用 uv 管理独立 Python 环境

在 WSL 中安装 Linux 版 uv：

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
uv --version
```

检查目标目录后，仅在创建新环境时执行下面的 `uv venv`。已经通过 `python -m venv` 创建的环境，可以继续由 uv 安装和管理依赖，无需为了换工具重新创建。

```bash
mkdir -p "$HOME/.venvs" "$HOME/src"
uv venv --python /usr/bin/python3 "$HOME/.venvs/cantera-726522be"

source "$HOME/.venvs/cantera-726522be/bin/activate"
export PATH="$HOME/.local/bin:$PATH"
```

显式使用 Ubuntu 的 `/usr/bin/python3`，使解释器与已安装的 `python3-dev` 头文件对应。Windows 中安装的 uv 或 Cantera 不作为这个 Linux 环境的构建工具。

安装 Python 构建依赖时，要把 Jinja2 一并装入：

```bash
uv pip install --python "$VIRTUAL_ENV/bin/python" \
  pip \
  'scons>=4.5,<5' \
  'Cython>=3.0.8,!=3.1.2,<4' \
  'numpy>=1.26.4,<3' \
  'ruamel.yaml>=0.17.21,<1' \
  'Jinja2>=2.10' \
  setuptools wheel packaging typing_extensions pytest
```

其中 `pip` 供 Cantera 的 Python 构建和安装过程内部调用。安装 pytest 只是准备依赖，不会执行测试。上述范围来自固定源码的构建要求；若要复现完整依赖集合，还应保存实际解析的版本清单：

```bash
uv pip freeze --python "$VIRTUAL_ENV/bin/python"
```

### 准备 Doxygen

固定源码要求 Doxygen 至少为 1.13。本次采用官方 1.18.0 Linux 二进制包，避免另行编译这个工具：

```bash
mkdir -p "$HOME/.local/opt/doxygen-1.18.0"
curl -fL https://www.doxygen.nl/files/doxygen-1.18.0.linux.bin.tar.gz \
  -o "$HOME/.local/opt/doxygen-1.18.0/archive.tar.gz"

printf '%s  %s\n' \
  '14fa81bdc34171edb5f1f02b1d60e74802f0439b77fa44e592565d517d72df90' \
  "$HOME/.local/opt/doxygen-1.18.0/archive.tar.gz" | sha256sum -c -
```

本次校验结果为 `OK`。校验成功后解压，再检查可执行文件：

```bash
tar -xzf "$HOME/.local/opt/doxygen-1.18.0/archive.tar.gz" \
  -C "$HOME/.local/opt/doxygen-1.18.0" --strip-components=1

export PATH="$HOME/.local/bin:$HOME/.local/opt/doxygen-1.18.0/bin:$PATH"
"$HOME/.local/opt/doxygen-1.18.0/bin/doxygen" --version
```

### 固定源码和子模块

在新的目标目录中克隆，然后切换到完整提交号，再初始化子模块：

```bash
git clone --filter=blob:none --no-checkout \
  https://github.com/Cantera/cantera.git \
  "$HOME/src/cantera-726522be"

cd "$HOME/src/cantera-726522be"
git checkout --detach 726522be4e2a13454d8415b7ef799d621f665cf3
git submodule update --init --recursive

git rev-parse HEAD
git status --short
git submodule status
```

本次主仓库提交与目标一致，工作区干净，子模块没有偏离主仓库记录的版本。子模块输出中的括号标签只作说明，不能代替提交号核对。

### 编译并安装

确认环境已激活、PATH 已补齐后，使用两个编译任务：

```bash
env -u CT_GIT_COMMIT "$VIRTUAL_ENV/bin/scons" build -j2 \
  python_package=y \
  python_cmd="$VIRTUAL_ENV/bin/python" \
  prefix="$VIRTUAL_ENV" \
  python_prefix="$VIRTUAL_ENV" \
  f90_interface=n \
  hdf_support=n \
  system_sundials=n \
  system_eigen=n \
  system_fmt=n \
  system_yamlcpp=n
```

这些选项把 C++ 库和 Python 包安装到独立环境，关闭本次不需要的 Fortran 和 HDF5，并使用固定子模块中的数值库。`env -u CT_GIT_COMMIT` 避免外部环境变量覆盖源码内嵌的提交标识。

构建输出包含 wheel `cantera-4.0.0a2-cp312-cp312-linux_x86_64.whl`，并最终显示：

```text
Compilation completed successfully
```

随后执行安装：

```bash
env -u CT_GIT_COMMIT "$VIRTUAL_ENV/bin/scons" install
```

安装成功信息中的 Python 包路径为：

```text
/home/subspace/.venvs/cantera-726522be/lib/python3.12/site-packages
```

构建和安装均由用户执行。`scons build`、`scons install` 与 `scons test` 是不同步骤；前两者成功不表示测试套件通过。

## 实际遇到的问题

### uv 文件存在但命令找不到

现象是 `uv: command not found`，但下面的绝对路径调用能正常输出 `uv 0.13.6`：

```bash
"$HOME/.local/bin/uv" --version
```

这说明可执行文件可用，应先检查命令搜索路径和环境激活顺序。不要只根据 `command not found` 反复重装工具。可用的定位命令是：

```bash
printf '当前用户：%s\n用户目录：%s\n' "$(id -un)" "$HOME"
ls -l "$HOME/.local/bin/uv" "$HOME/.local/bin/env"
```

本次确认文件位于 `/home/subspace/.local/bin/uv`，属于当前用户。随后发现操作顺序很关键：先补 PATH 再重新激活虚拟环境，可能让激活脚本恢复保存的旧 PATH，使刚补的 uv、Doxygen 路径再次消失。把顺序改成“先激活，再补 PATH”后继续安装依赖并完成构建。

uv 是命令行程序，不需要启动后台服务或重启。新终端要恢复的是环境和路径。

### 关闭文档后构建仍调用 Doxygen

首次构建停在：

```text
doxygen build/doc/Doxyfile_xml
sh: 1: doxygen: not found
scons: *** [build/doc/Cantera.tag] Error 127
```

原始依赖清单遗漏了 Doxygen 和 Jinja2。这个固定提交的默认构建会生成 CLib 接口代码：先由 Doxygen 生成标签信息，再由 Python 代码生成器和 Jinja2 生成接口源码。关闭 HTML 文档不会移除这条构建依赖。

修复措施是补齐符合版本要求的 Doxygen 和环境内的 Jinja2，再使用原构建命令继续。已有产物可由 SCons 复用，不必因为缺少工具就清空构建目录或更换 Cantera 提交。

## 环境验收

安装完成后，在 WSL 执行参考脚本的环境核对模式：

```bash
ARRHENIUS_REPO=/mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl
CT4_SOURCE="$HOME/src/cantera-726522be"

python "$ARRHENIUS_REPO/test/cantera_parity/reactor_reference.py" \
  --source-dir "$CT4_SOURCE" \
  --check-environment
```

该模式核对来源，不构造或求解反应器。本次用户返回的关键结果是：

```text
cantera_version       4.0.0a2
cantera_git_commit    726522be4
source_commit        726522be4e2a13454d8415b7ef799d621f665cf3
source_tracked_clean true
python_version       3.12.3
sundials_version     7.5.0
phase                ohmech
status               environment_checked_only
```

实际导入的 Python 扩展也位于独立环境的 `site-packages/cantera/`。固定机制 `h2o2.yaml` 的 LF 规范化 SHA-256 为：

```text
0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4
```

验收要同时看版本、提交号、源码状态、实际导入路径和机制摘要。只看到 `4.0.0a2`，不足以确认正在使用同一次源码构建。`environment_checked_only` 表示环境关卡通过；反应器参考求解、Julia 对比和覆盖表验收使用各自的运行记录。

## 以后配置同类环境时的做法

- 先盘点已有系统与工具，再补缺项。本次已有 WSL 2、Ubuntu 24.04 和 Python，无需从系统安装开始重做。
- 分清 Windows PowerShell 与 WSL Bash，明确每条命令在哪个终端运行。
- 对齐系统 Python 与开发头文件；把参考环境和旧项目环境隔离。
- 固定完整源码提交及子模块，同时记录实际安装的依赖版本。
- 使用绝对路径区分“文件不存在”和“命令搜索不到”，先激活环境，再补 PATH。
- 根据失败目标追踪依赖。文档工具也可能是源码生成工具，不能仅凭工具名称判断是否需要。
- 把编译成功、安装成功、环境就绪和数值测试通过分别验收。出现问题时先定位所在阶段，再决定修改什么。

## 参考资料

- [固定版本的依赖要求](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/doc/sphinx/develop/compiling/dependencies.md)
- [固定版本的构建选项](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/SConstruct)
- [默认 CLib 构建规则](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/interfaces/clib/SConscript)
- [uv 安装方式](https://docs.astral.sh/uv/getting-started/installation/)
- [uv 虚拟环境管理](https://docs.astral.sh/uv/pip/environments/)
- [Doxygen 官方下载与校验值](https://www.doxygen.nl/download.html)
