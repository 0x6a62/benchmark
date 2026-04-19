# benchmark

Simple benchmarking library for Zig projects

# Components

* Modules
  * benchmark
* Example usage
  * main.zig 

# Development

Zig target version: 0.16.0

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

## Add to your `build.zig` for benchmark/smoke flag support
```
// Benchmark supports running in two modes.
// Only run benchmarks:
// zig build test -Doptimize=ReleaseFast -- benchmark
const benchmark_arg = for (b.args orelse &.{}) |arg| {
    if (std.mem.indexOf(u8, arg, "benchmark") != null) break true;
} else false;

const mod = // your module

const benchmark = b.dependency("benchmark", .{
    .target = target,
    .optimize = optimize,
    .benchmark_arg = benchmark_arg,
});
mod.addImport("benchmark", benchmark.module("benchmark"));
```

## Using in code
```
const benchmark = @import("benchmark");

test "benchmark example" {
    const report_file = "_benchmark/benchmark_example";
    if (benchmark.getMode() != .benchmark) return;

    const io = std.testing.io;
    const allocator = std.testing.allocator;
    var buffer: [1024]u8 = undefined;

    var report = try benchmark.ReportWriter.init(io, report_file, &buffer);
    defer report.deinit(io);

    var bench = try benchmark.Benchmark().init(io, allocator, .{
        .mode = benchmark.Mode.benchmark,
        .size = 2,
    });
    defer bench.deinit(allocator);

    ...

    try bench.printResults(report.writer(), "benchmark - example");

    try report.writer().flush();
}
```

