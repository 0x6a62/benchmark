////////////////////////////////////
// Simple benchmarking functionality

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

/// Benchmarking results
/// Times are in ns
const Result = struct {
    name: []const u8,
    avg: u64,
    min: u64,
    max: u64,

    pub fn empty() Result {
        return Result{
            .name = "",
            .avg = 0,
            .min = 0,
            .max = 0,
        };
    }
};

const FnInterface = fn () void;

/// Benchmark mode
pub const Mode = enum {
    smoke,
    benchmark,
};

/// Benchmark config
const Config = struct {
    mode: Mode = .benchmark,
    size: usize = 1,
};

/// Benchmarking
pub fn Benchmark() type {
    return struct {
        _timer: std.time.Timer,
        _current_name: []const u8,
        _mode: Mode,
        results: []Result,
        current: usize,
        size: usize,

        const Self = @This();

        /// Init
        pub fn init(allocator: Allocator, config: Config) !Self {
            const size = config.size;
            const mode = config.mode;

            const results = try allocator.alloc(Result, size);
            for (0..size) |i| {
                results[i] = Result.empty();
            }

            return Self{
                ._timer = try std.time.Timer.start(),
                ._current_name = "",
                ._mode = mode,
                .results = results,
                .current = 0,
                .size = size,
            };
        }

        /// Deinit
        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.results);
        }

        /// Run a function, and record execution time
        /// Supports running multiple times, in order to get avg, etc.
        pub fn run(self: *Self, name: []const u8, comptime iterations: usize, f: *const FnInterface) !Result {
            std.debug.assert(self.current < self.size);

            var results = [_]u64{0} ** iterations;

            var timer = try std.time.Timer.start();
            for (0..iterations) |i| {
                // Setup
                timer.reset();

                // Run
                f();
                const t = timer.lap();
                results[i] = t;

                // Cleanup
            }

            // Calculate avg, min, max, etc for a function's multiple executions
            var avg: u64 = std.math.maxInt(u64);
            var min: u64 = std.math.maxInt(u64);
            var max: u64 = 0;
            var sum: u64 = 0;
            for (results) |x| {
                sum += x;
                if (x < min) min = x;
                if (x > max) max = x;
            }
            avg = @divTrunc(sum, iterations);

            const final_result = Result{
                .name = name,
                .avg = avg,
                .min = min,
                .max = max,
            };

            self.results[self.current] = final_result;
            self.current += 1;

            return final_result;
        }

        /// Start timer for bencharking instance
        pub fn start(self: *Self, name: []const u8) !void {
            self._current_name = name;
            self._timer.reset();
        }

        /// Stop timer (and record) for bencharking instance
        pub fn stop(self: *Self) Result {
            std.debug.assert(self.current < self.size);

            const t = self._timer.lap();

            const final_result = Result{
                .name = self._current_name,
                .avg = t,
                .min = t,
                .max = t,
            };

            self.results[self.current] = final_result;
            self.current += 1;

            // cleanup
            self._current_name = "";

            return final_result;
        }

        /// Print results
        pub fn printResults(self: Self, writer: *std.Io.Writer, header: []const u8) !void {
            if (header.len > 0) {
                try writer.print("# {s}\n", .{header});
            }

            try writer.print("{s:<20} {s:>15} {s:>15} {s:>15} {s:>10}\n", .{
                "Name",
                "Average (ns)",
                "Min (ns)",
                "Max (ns)",
                "Diff",
            });

            try writer.print("-------------------------------------------------------------------------------\n", .{});

            const base = self.results[0];
            for (self.results) |result| {
                const avg: f64 = @floatFromInt(result.avg);
                const base_avg: f64 = @floatFromInt(base.avg);
                const ratio = avg / base_avg;

                try writer.print("{s:<20} {d:>15} {d:>15} {d:>15} {d:>10.2}\n", .{
                    result.name,
                    result.avg,
                    result.min,
                    result.max,
                    ratio,
                });
            }
        }
    };
}

////////
// Tests

/// Get benchmarking mode
fn getBenchmarkMode() Mode {
    return if (@import("test_options").benchmark) .benchmark else .smoke;
}

/// Example function for testing benchmark
fn example() void {
    std.debug.print("example\n", .{});
}

test "Example usage - One run" {
    var da = std.heap.DebugAllocator(.{}).init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var bench = try Benchmark().init(allocator, .{ .mode = getBenchmarkMode(), .size = 1 });
    defer bench.deinit(allocator);
    const results = try bench.run("example", 2, example);
    // try stdout.print("{s}: {d} {d} {d}\n", .{ results.name, results.avg, results.min, results.max });

    try std.testing.expect(results.avg > 0);
    try std.testing.expect(results.avg < 10000);

    try stdout.flush();
}

test "Example usage - Multiple runs " {
    var da = std.heap.DebugAllocator(.{}).init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var bench = try Benchmark().init(allocator, .{ .mode = getBenchmarkMode(), .size = 2 });
    defer bench.deinit(allocator);

    _ = try bench.run("example1", 2, example);
    _ = try bench.run("example2", 2, example);
    // try bench.printResults(stdout);

    try std.testing.expect(bench.current == 2);

    try stdout.flush();
}

test "Example usage - Separate blocks" {
    // This test would only run in benchmark mode
    //if (getMode() == .smoke) return;

    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const allocator = da.allocator();

    var stderr_buffer: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;

    var bench = try Benchmark().init(allocator, .{ .mode = getBenchmarkMode(), .size = 3 });
    defer bench.deinit(allocator);

    {
        try bench.start("example1");
        example();
        _ = bench.stop();
    }
    {
        try bench.start("example2");
        example();
        _ = bench.stop();
    }
    {
        try bench.start("example3");
        example();
        _ = bench.stop();
    }

    try bench.printResults(stderr, "Examples");

    try stderr.flush();
}

test "benchmark parameter test" {
    // Example: zig build test -- benchmark

    std.debug.print("MODE: {any}\n", .{getBenchmarkMode()});

    if (getBenchmarkMode() == .smoke) return;

    std.debug.print("running a fake benchmark...\n", .{});
}
