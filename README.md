# benchmark

Simple benchmarking library for Zig projects

# Components

* Modules
  * benchmark
* Example usage
  * main.zig 

# Development

Zig target version: 0.15.2

```
# Build
zig build

# Run
zig build run

# Test
zig build test --summary all
```

# Usage

## Install
```
zig fetch --save git+https://github.com/0x6a62/benchmark.git
```

## Add to your `build.zig`
```
const benchmark = b.dependency("benchmark", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("benchmark", benchmark.module("benchmark"));
```

## Add to your `build.zig` for benchmark/smoke flag support

```
const test_options = b.addOptions();
// Benchmark supports running in two modes.
// - ./zig/zig build test
// - ./zig/zig build --Doptimize=ReleaseFast fast test -- benchmark
test_options.addOption(bool, "benchmark", for (b.args orelse &.{}) |arg| {
    if (std.mem.indexOf(u8, arg, "benchmark") != null) break true;
} else false);

// Depending how you use it:
mod.addOptions("test_options", test_options);
mod.root_module.addOptions("test_options", test_options);
```

## Using in code
```
const benchmark = @import("benchmark");

if (benchmark.getMode() == .smoke) return;
```

