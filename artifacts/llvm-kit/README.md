# ICU4C Portable LLVM IR Kit

This kit contains [ICU4C](https://icu.unicode.org/) source modules compiled into LLVM IR (`.ll`) using Clang, along with public headers. You can use this to build ICU for **any target platform** that supports LLVM.

---

## 📦 Included

```
llvm-ir-18/
  └── linux-x86_64-clang-18/
      ├── common/
      ├── i18n/
      ├── io/
      └── ...

include/
  └── unicode/
      ├── utypes.h
      ├── ustring.h
      └── ...
```

---

## ⚖️ How to Build a Static Library

You can compile the `.ll` files into platform-specific `.o` object files and then archive them into a `.a` static library.

### ✅ Requirements

- `clang` and `ar` (from LLVM)
- Optional: GNU `find`, `bash`, `make`

---

### 🛠️ Quick Start

```bash
./build-lib-from-llvm.sh x86_64-linux-gnu 18
```

- First argument is the target triple (e.g. `x86_64-linux-gnu`, `x86_64-w64-windows-gnu`, `wasm32`)
- Second argument is the LLVM version used in the IR folder name (e.g. `18`)

Output:
```
lib-from-llvm/
├── lib/libicu-llvm.a
└── obj/**/*.o
```

You can now link this `.a` into your project like any other static ICU library.

---

## 🤔 Why LLVM IR?

- Platform-agnostic: compile once, reuse anywhere
- Easy inspection and transformation
- Smaller and faster to ship than full source
- Enables custom builds, lightweight toolchains, or JITs

---

## ⚠️ Known Limitations

- Some legacy layout files are excluded (they require `LETypes.h`, removed in ICU 64+)
- ICU data files (`icudt77l.dat`) are not included; you must package them separately if needed

---

## 📚 References

- ICU Project: https://icu.unicode.org/
- LLVM IR: https://llvm.org/docs/LangRef.html
- Clang Targets: https://clang.llvm.org/docs/CrossCompilation.html

---

## 📝 License

This kit is based on ICU4C and subject to the [ICU License](https://github.com/unicode-org/icu/blob/main/LICENSE).
