////////////////////////////////////
// Simple benchmarking functionality

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const Io = std.Io;

/// Benchmark errors
pub const BenchmarkError = error{
    InvalidReportPath,
};

/// Benchmarking results
/// Times are in ns
const Result = struct {
    name: []const u8,
    avg: i96,
    min: i96,
    max: i96,

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
    /// Don't run benchmarks
    smoke,
    /// Run benchmarks
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
        _timer: Io.Timestamp,
        _current_name: []const u8,
        _mode: Mode,
        results: []Result,
        current: usize,
        size: usize,

        const Self = @This();

        /// Init
        pub fn init(io: Io, allocator: Allocator, config: Config) !Self {
            const size = config.size;
            const mode = config.mode;

            const results = try allocator.alloc(Result, size);
            for (0..size) |i| {
                results[i] = Result.empty();
            }

            return Self{
                ._timer = Io.Timestamp.now(io, Io.Clock.awake),
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
        pub fn run(self: *Self, io: Io, name: []const u8, comptime iterations: usize, f: *const FnInterface) !Result {
            std.debug.assert(self.current < self.size);

            var results = [_]i96{0} ** iterations;

            var timer = Io.Timestamp.now(io, Io.Clock.awake);
            for (0..iterations) |i| {
                // Setup
                timer = Io.Timestamp.now(io, Io.Clock.awake);

                // Run
                f();
                const t = timer.untilNow(io, Io.Clock.awake);
                results[i] = t.toNanoseconds();

                // Cleanup
            }

            // Calculate avg, min, max, etc for a function's multiple executions
            var avg: i96 = std.math.maxInt(i96);
            var min: i96 = std.math.maxInt(i96);
            var max: i96 = 0;
            var sum: i96 = 0;
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
        pub fn start(self: *Self, io: Io, name: []const u8) !void {
            self._current_name = name;
            self._timer = Io.Timestamp.now(io, Io.Clock.awake);
        }

        /// Stop timer (and record) for bencharking instance
        pub fn stop(self: *Self, io: Io) Result {
            std.debug.assert(self.current < self.size);

            const t = self._timer.untilNow(io, Io.Clock.awake);

            const final_result = Result{
                .name = self._current_name,
                .avg = t.toNanoseconds(),
                .min = t.toNanoseconds(),
                .max = t.toNanoseconds(),
            };

            self.results[self.current] = final_result;
            self.current += 1;

            // cleanup
            self._current_name = "";

            return final_result;
        }

        /// Print results
        pub fn printResults(self: Self, writer: *Io.Writer, header: []const u8) !void {
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

/// Contains file and writer for creating benchmark reports
/// This is a helper for creating and writing to benchmark reports
/// Note: filename must start with '_benchmark', this is to
/// provide a safey bounndary so you don't overwrite normal files
pub const ReportWriter = struct {
    // Filehandle
    _file: Io.File,
    // File writer
    _writer: Io.File.Writer,

    const Self = @This();

    /// Init ReportWriter
    pub fn init(io: Io, file_name: []const u8, buffer: []u8) !Self {
        if (!std.mem.startsWith(u8, file_name, "_benchmark")) {
            return BenchmarkError.InvalidReportPath;
        }

        const file = try Io.Dir.createFile(.cwd(), io, file_name, .{});
        errdefer file.close(io);

        return Self{
            ._file = file,
            ._writer = file.writer(io, buffer),
        };
    }

    /// Deinit and close file
    pub fn deinit(self: *Self, io: Io) void {
        self._file.close(io);
    }

    /// Provide a writer
    pub fn writer(self: *Self) *Io.Writer {
        return &self._writer.interface;
    }
};

////////
// Tests

/// Get benchmarking mode
fn getBenchmarkMode() Mode {
    return if (@import("test_options").benchmark) .benchmark else .smoke;
}

/// Example function for testing benchmark
fn example() void {
    var total: usize = 0;
    for (0..10) |i| {
        total += i * 2;
    }
}

test "Example usage - One run" {
    const report_file = "_benchmark/benchmark_example_one_run";

    const io = std.testing.io;
    const allocator = std.testing.allocator;
    var buffer: [1024]u8 = undefined;

    var report = try ReportWriter.init(io, report_file, &buffer);
    defer report.deinit(io);

    var bench = try Benchmark().init(io, allocator, .{
        .mode = getBenchmarkMode(),
        .size = 1,
    });
    defer bench.deinit(allocator);

    const results = try bench.run(io, "example - one run", 2, example);
    try report.writer().print("{s}: {d} {d} {d}\n", .{
        results.name,
        results.avg,
        results.min,
        results.max,
    });

    try std.testing.expect(results.avg > 0);
    try std.testing.expect(results.avg < 1000000);

    try report.writer().flush();
}

test "Example usage - Multiple runs " {
    const report_file = "_benchmark/benchmark_example_multiple_runs";

    const io = std.testing.io;
    const allocator = std.testing.allocator;
    var buffer: [1024]u8 = undefined;

    var report = try ReportWriter.init(io, report_file, &buffer);
    defer report.deinit(io);

    var bench = try Benchmark().init(io, allocator, .{
        .mode = getBenchmarkMode(),
        .size = 2,
    });
    defer bench.deinit(allocator);

    _ = try bench.run(io, "example1", 2, example);
    _ = try bench.run(io, "example2", 2, example);
    try bench.printResults(report.writer(), "multiple runs");

    try std.testing.expect(bench.current == 2);

    try report.writer().flush();
}

test "Example usage - Separate blocks" {
    const report_file = "_benchmark/benchmark_example_separate_blocks";

    const io = std.testing.io;
    const allocator = std.testing.allocator;
    var buffer: [1024]u8 = undefined;

    var report = try ReportWriter.init(io, report_file, &buffer);
    defer report.deinit(io);

    var bench = try Benchmark().init(io, allocator, .{
        .mode = getBenchmarkMode(),
        .size = 3,
    });
    defer bench.deinit(allocator);

    {
        try bench.start(io, "example1");
        example();
        _ = bench.stop(io);
    }
    {
        try bench.start(io, "example2");
        example();
        _ = bench.stop(io);
    }
    {
        try bench.start(io, "example3");
        example();
        _ = bench.stop(io);
    }

    try bench.printResults(report.writer(), "Examples");

    try report.writer().flush();
}

test "benchmark parameter test" {
    // This test only runs in benchmark mode
    // Example: zig build test -- benchmark
    if (getBenchmarkMode() != .benchmark) return;
    const report_file = "_benchmark/benchmark_parameter_test";

    const io = std.testing.io;
    var buffer: [1024]u8 = undefined;

    var report = try ReportWriter.init(io, report_file, &buffer);
    defer report.deinit(io);

    try report.writer().print("running a fake benchmark...\n", .{});
    try report.writer().print("Now: {any}\n", .{Io.Timestamp.now(io, Io.Clock.real).toSeconds()});

    try report.writer().flush();
}

test "ReportWriter - InvalidReportPath check" {
    const report_file = "BAD_benchmark/reportwriter_invalidreportpath_check";

    const io = std.testing.io;
    var buffer: [1024]u8 = undefined;

    const report = ReportWriter.init(io, report_file, &buffer);

    try std.testing.expect(report == BenchmarkError.InvalidReportPath);
}
