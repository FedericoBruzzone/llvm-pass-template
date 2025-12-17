Development Environment
=======================

## Platform Support And Requirements
In order to build the passes, you will need:
* LLVM 21
* C++ compiler that supports C++17
* CMake 3.20 or higher

In order to run the passes, you will need:
* `clang-21` to generate input LLVM files, e.g., `clang -fno-discard-value-names -S -emit-llvm file.c -o file.ll`
* [`opt`](http://llvm.org/docs/CommandGuide/opt.html) to run the passes, e.g.,
  `opt -load-pass-plugin ./build/lib/libMyPass.dylib --passes="my-pass" -S input.ll -o output.ll`

There are additional requirements for tests (these will be satisfied by
installing LLVM 21):
* [`lit`](https://llvm.org/docs/CommandGuide/lit.html) (i.e., `llvm-lit`) LLVM tool for executing the tests.
* [`FileCheck`](https://llvm.org/docs/CommandGuide/FileCheck.html) (LIT requirement, it's used to check whether tests generate the expected output).


## Installing LLVM 21 on Mac OS X
On Darwin you can install LLVM 21 with [Homebrew](https://brew.sh/):

```bash
brew install llvm@21
```

If you already have an older version of LLVM installed, you can upgrade it to
LLVM 21 like this:

```bash
brew upgrade llvm
```

Once the installation (or upgrade) is complete, all the required header files,
libraries and tools will be located either `/usr/local/opt/llvm` (on Intel Macs) or `/opt/homebrew/opt/llvm/` (on Apple Silicon Macs).

## Installing LLVM 21 on Ubuntu
On Ubuntu Jammy Jellyfish, you can install modern LLVM from the official
[repository](http://apt.llvm.org/):

```bash
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add -
sudo apt-add-repository "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-21 main"
sudo apt-get update
sudo apt-get install -y llvm-21 llvm-21-dev llvm-21-tools clang-21
```
This will install all the required header files, libraries and tools in
`/usr/lib/llvm-21/`.

## Building LLVM 21 From Sources
Building from sources can be slow and tricky to debug. It is not necessary, but
might be your preferred way of obtaining LLVM 21. The following steps will work
on Linux and Mac OS X:

```bash
git clone https://github.com/llvm/llvm-project.git
cd llvm-project
git checkout release/21.x
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=host -DLLVM_ENABLE_PROJECTS=clang <llvm-project/root/dir>/llvm/
cmake --build .
```
For more details read the [official documentation](https://llvm.org/docs/CMake.html).
