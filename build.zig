const std = @import("std");
const Mode = @import("number-parsing.zig").Mode;

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const use_std = b.option(
        bool,
        "use-std",
        "use the std lib implementation",
    ) orelse false;
    const mode = b.option(
        Mode,
        "mode",
        "mode. defaults to bench.",
    ) orelse .bench;
    const build_options = b.addOptions();
    build_options.addOption(bool, "use_std", use_std);
    build_options.addOption(Mode, "mode", mode);

    const exe = b.addExecutable(.{
        .name = "number-parsing",
        .root_source_file = .{ .path = "number-parsing.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);
    exe.addOptions("build_options", build_options);

    const run_step = b.step("run", "Run the exe");
    const exe_run = b.addRunArtifact(exe);
    exe_run.has_side_effects = true;
    run_step.dependOn(&exe_run.step);

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "number-parsing.zig" },
        .target = target,
        .optimize = optimize,
    });
    tests.addOptions("build_options", build_options);
    tests.filter = b.option([]const u8, "test-filter", "test filter") orelse "";
    const run_tests = b.step("test", "Run the tests");
    const test_run = b.addRunArtifact(tests);
    test_run.has_side_effects = true;
    run_tests.dependOn(&test_run.step);
}
