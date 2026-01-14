const std = @import("std");
const benchmark = @import("benchmark");
const Allocator = std.mem.Allocator;
const math = std.math;
const print = std.debug.print;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    ////////////
    // Example 1

    {
        var bench = try benchmark.Benchmark().init(allocator, 1);
        const results = try bench.run("example1", 2, example1);
        print("{s}: {d} {d} {d}\n", .{ results.name, results.avg, results.min, results.max });
    }

    ////////////
    // Example 2

    {
        var bench = try benchmark.Benchmark().init(allocator, 2);
        _ = try bench.run("example1", 2, example1);
        _ = try bench.run("example2", 2, example1);
        try bench.printResults(stdout);
    }

    ////////////
    // Example 3

    {
        var bench = try benchmark.Benchmark().init(allocator, 3);

        {
            try bench.start("example3");
            example1();
            _ = bench.stop();
        }
        {
            try bench.start("example4");
            example1();
            _ = bench.stop();
        }
        {
            try bench.start("example5");
            example1();
            _ = bench.stop();
        }

        try bench.printResults(stdout);
    }

    try stdout.print("### done\n", .{});
    try stdout.flush();
}

pub fn example1() void {
    print("example1\n", .{});
}
