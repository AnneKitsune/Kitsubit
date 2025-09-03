const std = @import("std");

pub const compileNds = @import("anne_nds_dev").compileNds;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const bench = b.dependency("anne_benchmark", .{.target = target, .optimize = optimize}).module("anne_benchmark");
    const table = b.dependency("anne_table", .{.target = target, .optimize = optimize}).module("anne_table");
    const uuid = b.dependency("anne_uuid", .{.target = target, .optimize = optimize}).module("anne_uuid");
    const dice  = b.dependency("anne_dice", .{.target = target, .optimize = optimize}).module("anne_dice");
    const nds_mod = b.dependency("anne_nds_dev", .{.target = target, .optimize = optimize}).module("anne_nds_dev");
    const log = b.dependency("anne_log", .{.target = target, .optimize = optimize}).module("anne_log");
    const bzip2 = b.dependency("anne_bzip2", .{.target = target, .optimize = optimize}).module("anne_bzip2");

    const mod = b.addModule("kitsubit", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "benchmark", .module = bench },
            .{ .name = "table", .module = table },
            .{ .name = "uuid", .module = uuid },
            .{ .name = "dice", .module = dice },
            .{ .name = "nds", .module = nds_mod },
            .{ .name = "log", .module = log },
            .{ .name = "bzip2", .module = bzip2 },
        },
    });

    // Lib export
    const lib = b.addLibrary(.{
        .name = "kitsubit",
        .root_module = mod,
    });
    b.installArtifact(lib);

    // Testing
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}


