const std = @import("std");
const math = std.math;

const build_options = @import("build_options");
const fmt = if (build_options.use_std) @import("fmt.zig") else @import("fmt-18158.zig");

pub const std_options = struct {
    pub const log_level = .err;
};

fn printNum(
    base: u8,
    int: anytype,
    fbs: *std.io.FixedBufferStream([]u8),
    random: std.rand.Random,
    add_underscores: u8,
    case: std.fmt.Case,
) !void {
    if (add_underscores == 0) {
        var buf: [256]u8 = undefined;
        var fbs2 = std.io.fixedBufferStream(&buf);
        try std.fmt.formatInt(int, base, case, .{}, fbs2.writer());
        var orig = fbs2.getWritten();

        // std.debug.print("orig={s}\n", .{orig});
        try fbs.writer().print("{s}", .{orig[0..1]});
        orig = orig[1..];
        while (orig.len > 1) {
            const advance = random.intRangeLessThan(usize, 1, orig.len);
            // std.debug.print("rest={s} advance={}\n", .{ orig, advance });
            try fbs.writer().print("{s}_", .{orig[0..advance]});
            orig = orig[advance..];
        }
        try fbs.writer().print("{s}", .{orig});
    } else try std.fmt.formatInt(int, base, case, .{}, fbs.writer());
}

const Ts: []const type = blk: {
    @setEvalBranchQuota(2000);
    var ts: []const type = &.{};
    inline for (0..129) |bits| {
        if (bits > 8 and bits % 4 != 0) continue;
        inline for (.{ .unsigned, .signed }) |signedness| {
            // TODO remove this line once https://github.com/ziglang/zig/issues/18157 is resolved
            if (signedness == .signed and (bits == 2 or bits == 4 or bits == 5)) continue;
            ts = ts ++ [1]type{std.meta.Int(signedness, bits)};
        }
    }
    // @compileLog(ts);
    break :blk ts;
};

pub const Mode = enum { bench, write };

pub fn main() !void {
    @setEvalBranchQuota(2000);

    var rand = std.rand.DefaultPrng.init(0);
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const bases = [_]u8{ 2, 8, 10, 16 };
    const formats = [_][2][]const u8{
        .{ "b", "B" },
        .{ "o", "O" },
        .{ "", "" },
        .{ "x", "X" },
    };

    if (build_options.mode == .write) {
        const file = try std.fs.cwd().createFile("numbers.txt", .{});
        defer file.close();
        var bw = std.io.bufferedWriter(file.writer());
        const writer = bw.writer();
        for (0..100_0) |_| {
            inline for (Ts, 0..) |T, Tidx| {
                for (bases ++ .{0}) |base| {
                    const info = @typeInfo(T);
                    const T2 = std.meta.Int(info.Int.signedness, info.Int.bits + 1);
                    const expected: T2 = rand.random().int(T);
                    fbs.pos = 0;
                    // std.debug.print("T={} expected={} base={}\n", .{ T, expected, base });
                    const add_underscores = rand.random().intRangeLessThan(u8, 0, 10);
                    const case = rand.random().enumValue(std.fmt.Case);
                    if (base == 0) {
                        const i = rand.random().uintLessThan(u8, bases.len);
                        const prefix = formats[i][@intFromEnum(case)];
                        if (expected < 0) {
                            _ = try fbs.writer().write("-0");
                            _ = try fbs.writer().write(prefix);
                            try printNum(bases[i], -expected, &fbs, rand.random(), add_underscores, case);
                        } else {
                            _ = try fbs.writer().write("0");
                            _ = try fbs.writer().write(prefix);
                            try printNum(bases[i], expected, &fbs, rand.random(), add_underscores, case);
                        }
                    } else {
                        try printNum(base, expected, &fbs, rand.random(), add_underscores, case);
                    }

                    // try writer.print("{} {s} {}\n", .{ Tidx, fbs.getWritten(), base });
                    try writer.writeInt(u8, Tidx, .little);
                    try writer.writeInt(u8, base, .little);
                    const s = fbs.getWritten();
                    _ = try writer.write(s);
                    try writer.writeByte('\n');
                    const U = comptime std.meta.Int(info.Int.signedness, ((info.Int.bits + 7) >> 3) << 3);
                    try writer.writeInt(U, @as(T, @truncate(expected)), .little);
                }
            }
        }
        try bw.flush();
    } else {
        const file = try std.fs.cwd().openFile("numbers.txt", .{});
        defer file.close();
        var br = std.io.bufferedReader(file.reader());
        const reader = br.reader();
        var buf2: [256]u8 = undefined;
        while (true) {
            const tidx = reader.readByte() catch |e| switch (e) {
                error.EndOfStream => break,
                else => return e,
            };
            if (tidx >= Ts.len) return error.InvalidTypeIndex;
            const base = try reader.readByte();
            const n = try reader.readUntilDelimiterOrEof(&buf2, '\n') orelse unreachable;
            // std.debug.print("tidx={} base={} n='{s}'/{any}\n", .{ tidx, base, n, n });
            switch (@as(u7, @intCast(tidx))) {
                inline else => |Tidx| if (Tidx < Ts.len) {
                    const T = Ts[Tidx];
                    const info = @typeInfo(T);
                    const U = comptime std.meta.Int(info.Int.signedness, ((info.Int.bits + 7) >> 3) << 3);
                    const expected = try reader.readInt(U, .little);

                    // std.debug.print(
                    //     "parseInt({}, \"{s}\", {}). expected={}\n",
                    //     .{ T, n, base, expected },
                    // );

                    const actual = fmt.parseInt(T, n, base) catch |e| {
                        std.log.err(
                            "parseInt({}, \"{s}\", {}) -> {s}. expected={}",
                            .{ T, n, base, @errorName(e), expected },
                        );
                        return e;
                    };
                    // std.debug.print(
                    //     "parseInt({}, \"{s}\", {}) -> {}. expected={}\n",
                    //     .{ T, n, base, actual, expected },
                    // );
                    try std.testing.expectEqual(expected, actual);
                },
            }
        }
    }
}

fn testOne(comptime T: type, comptime expected: comptime_int, err: ?anyerror, base: u8) !void {
    var buf: [256]u8 = undefined;
    const len = std.fmt.formatIntBuf(&buf, expected, base, .lower, .{});
    const s = buf[0..len];
    const test_fmt =
        \\test {{
        \\    // {s}
        \\    try std.testing.expectEqual(@as({s}, {}), try std.fmt.parseInt({1s}, "{s}", {}));
        \\}}
        \\
    ;
    if (err == null and comptime std.math.cast(T, expected) != null) {
        const actual = fmt.parseInt(T, s, base) catch |e| {
            std.debug.print(test_fmt, .{ @errorName(e), @typeName(T), expected, s, base });
            return;
        };

        try std.testing.expectEqual(@as(T, expected), actual);
    } else if (err != null) {
        try std.testing.expectError(err.?, fmt.parseInt(T, s, base));
    }
}

test "parseInt Ts - print failing test cases" {
    // @setEvalBranchQuota(2000);
    inline for (Ts) |T| {
        for (2..37) |baseu| {
            const base: u8 = @truncate(baseu);
            try testOne(T, std.math.maxInt(T), null, base);
            try testOne(T, std.math.maxInt(T) - 1, null, base);
            try testOne(T, std.math.maxInt(T) + 1, error.Overflow, base);

            try testOne(T, std.math.minInt(T), null, base);
            try testOne(T, std.math.minInt(T) - 1, error.Overflow, base);
            try testOne(T, std.math.minInt(T) + 1, null, base);
        }
    }
}
