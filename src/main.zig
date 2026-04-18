// Example usage

const std = @import("std");
const benchmark = @import("benchmark");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const math = std.math;
const print = std.debug.print;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    ////////////
    // Example 1

    {
        var bench = try benchmark.Benchmark().init(io, allocator, .{ .size = 1 });
        const results = try bench.run(io, "example1", 2, example1);
        print("{s}: {d} {d} {d}\n", .{ results.name, results.avg, results.min, results.max });
    }

    ////////////
    // Example 2

    {
        var bench = try benchmark.Benchmark().init(io, allocator, .{ .size = 2 });
        _ = try bench.run(io, "example1", 2, example1);
        _ = try bench.run(io, "example2", 2, example1);
        try bench.printResults(stdout, "Example 2");
    }

    ////////////
    // Example 3

    {
        var bench = try benchmark.Benchmark().init(io, allocator, .{ .size = 3 });

        {
            try bench.start(io, "example3");
            example1();
            _ = bench.stop(io);
        }
        {
            try bench.start(io, "example4");
            example1();
            _ = bench.stop(io);
        }
        {
            try bench.start(io, "example5");
            example1();
            _ = bench.stop(io);
        }

        try bench.printResults(stdout, "Example 3");
    }

    try stdout.print("### done\n", .{});
    try stdout.flush();
}

pub fn example1() void {
    print("example1\n", .{});
}
