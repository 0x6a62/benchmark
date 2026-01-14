# benchmark-zig

Simple benchmarking library

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
zig fetch --save git+https://github.com/0x6a62/benchmark-zig.git
```

## Add to your `build.zig`
```
const benchmark = b.dependency("benchmark", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("benchmark", benchmark.module("benchmark"));
```

## Using in code
```
const benchmark = @import("benchmark");
```

