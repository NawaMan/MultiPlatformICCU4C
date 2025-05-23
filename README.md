# 🌐 MultiPlatform ICU4C Builder

Prebuild [ICU4C (International Components for Unicode)](https://icu.unicode.org/) as **static libraries** for multiple platforms — including Linux, Windows, MacOS, and WebAssembly.

This project simplifies using ICU in downstream projects by offering **precompiled packages**, version-controlled builds, and optional LLVM IR outputs — ideal for cross-platform projects, embedded runtimes, and CI pipelines.

---

## ✅ Features

- 🔨 **Static ICU builds**: Easier linking, no runtime dependency issues.
- 🧪 **Supports multiple targets**:
  - Linux (Clang 18, x86_64 and x86)
  - Windows (MinGW via Clang cross-targets)
  - WebAssembly (32-bit and 64-bit via Emscripten)
  - macOS (Intel, ARM, or Universal binaries)
- 📦 **Pre-packaged ZIP output** for each target
- 🧠 **LLVM IR / Bitcode output** for advanced use cases (e.g., link-time optimization, WASM toolchains)
- 🚀 **GitHub Actions support** for reproducible release builds

---

## Build Instructions

### Note on Platform Support

- The `quick-build.sh` script only works on Linux systems.
- For Windows builds, you must use the full Docker-based build process with `full-build.sh`.
- For macOS, use the specialized `mac-build.sh` script.

---

## 📦 Versions

The versions of ICU, Clang, and Emscripten SDK are specified in the [`versions.env`](./versions.env) file at the root of this repository. This file is the single source of truth for the main build component versions used by all build scripts (see also `build.sh`).

If you need to build with different versions of ICU, Clang, or Emscripten, simply clone this repository and edit `versions.env` to your desired values.

The current release is `1.0.0` and the versions of the component are as follows:

| Component      | Version   |
|----------------|-----------|
| ICU            | `77.1`    |
| Clang          | `18.x`    |
| Emscripten SDK | `4.0.6`   |


---

## 🧰 How It Works

This repo includes:

| Script          | Purpose                                                              |
|-----------------|----------------------------------------------------------------------|
| `full-build.sh` | GitHub Actions entry point (Docker-based full build)                 |
| `quick-build.sh`| Lightweight local build for Linux only (Clang)                       |
| `.github/workflows/release.yaml` | Manual GitHub-triggered release workflow            |

Support scripts:

| Script          | Purpose                                                              |
|-----------------|----------------------------------------------------------------------|
| `build.sh`      | Main cross-platform build orchestrator (Linux, Windows, WASM, etc.)  |
| `mac-build.sh`  | Specialized macOS build script supporting Universal binaries         |
| `.github/workflows/release.yaml` | Manual GitHub-triggered release workflow            |

---

## 🚀 GitHub Release Workflow

Run the GitHub Actions workflow **manually** to create a full release:

1. Trigger the [Release (Manual)](https://github.com/NawaMan/MultiPlatformICCU4C/actions) workflow
2. Optionally enter a version (or it reads from `version.txt`)
3. It builds:
   - Linux (Clang)
   - Windows (Clang cross-compile)
   - WebAssembly (with Emscripten)
   - macOS (Universal binary)
4. It:
   - Uploads all artifacts
   - Extracts changelog section
   - Tags + publishes a GitHub Release

If the action is run in release branch, the release version will be published.
Otherwise, the snapshot version will be published.

---

## 📂 Output Example

After build, all artifacts are stored in `dist/`:

```
dist/
├── icu4c-77.1-linux-x86_32-clang-18.zip
├── icu4c-77.1-linux-x86_64-clang-18.zip
├── icu4c-77.1-llvm-kit-32-clang-18.zip
├── icu4c-77.1-llvm-kit-64-clang-18.zip
├── icu4c-77.1-macos-arm64-clang-18.zip
├── icu4c-77.1-macos-universal-clang-18.zip
├── icu4c-77.1-macos-x86_64-clang-18.zip
├── icu4c-77.1-wasm32-ensdk-4.0.6.zip
├── icu4c-77.1-wasm64-ensdk-4.0.6.zip
├── icu4c-77.1-windows-x86-32-clang-18.zip
├── icu4c-77.1-windows-x86_64-clang-18.zip
├── Source code (zip)
└── Source code (tar.gz)
```


Each ZIP includes:

- `include/`: All ICU headers
- `lib/`: Prebuilt `.a` static libraries
- `bin/` *(if tools enabled)*

---

## 🧪 Local Build

You can run a local build on Linux using:

```bash
./quick-build.sh
```

Or for all platforms (requires Docker):

```bash
./full-build.sh
```

---

🛠️ Requirements

For local builds (non-Docker):

    Linux or macOS host

    Clang 18

    wget, make, zip, rsync

    For WebAssembly: emsdk (auto-installed)

    For Windows builds: clang with --target support (x86_64-w64-windows-gnu)

🔧 Advanced: LLVM IR Output

You can enable generation of .ll and .bc files from ICU source files via Clang or Emscripten.

Use these for:

    Custom link-time analysis

    WASM runtimes

    Further compilation pipelines (e.g., Mojo 🔥)

---

❤️ Credits

    ICU Project: https://icu.unicode.org

    Emscripten: https://emscripten.org

    GitHub Actions CI/CD magic

📄 License

This project wraps ICU and provides a build system around it. ICU is licensed under the Unicode License.

See LICENSE for full details.