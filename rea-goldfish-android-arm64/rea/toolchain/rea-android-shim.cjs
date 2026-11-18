// Standalone Android/arm64 platform shim for REA.
// Use it without patching REA:
//   NODE_OPTIONS="--require=$HOME/tools/rea-android-shim.cjs" rea ...
// Or let install.sh copy it into REA's launcher automatically.
if (process.platform === "android") {
  Object.defineProperty(process, "platform", {
    value: "linux",
    configurable: true,
    enumerable: true,
    writable: false,
  });
}