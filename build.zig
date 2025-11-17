const std = @import("std");

pub const compileNds = @import("anne_nds_dev").compileNds;

const emulator_nds = "melonDS";

const EngineTarget = enum {
    /// Whatever was passed with -Dtarget=
    native,
    /// Nintendo DS homebrew
    nds,
};

const Target = struct {
    named: EngineTarget,
    resolved: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,

    const S = @This();
    pub fn link(s: *S) !void {
        switch (s.named) {
            .native => {}, // do nothing
            // TODO
            .nds => {},
        }
    }
    pub fn run(s: *S) !void {
        _ = s;
    }
    pub fn run_test(s: *S) !void {
        _ = s;
    }
};

pub fn build(b: *std.Build) void {
    // Selects if we have a normal build or a nintendo ds build.
    // If true, we'll build a .nds file for `zig build` and for `zig build run` we'll run melonDS.
    const nds = b.option(bool, "nds", "Build for Nintendo DS") orelse false;

    const optimize = b.standardOptimizeOption(.{});
    const target = resolveTarget(b, optimize, nds);

    const bench = b.dependency("anne_benchmark", .{ .target = target.resolved, .optimize = target.optimize }).module("anne_benchmark");
    const table = b.dependency("anne_table", .{ .target = target.resolved, .optimize = target.optimize }).module("anne_table");
    const uuid = b.dependency("anne_uuid", .{ .target = target.resolved, .optimize = target.optimize }).module("anne_uuid");
    const dice = b.dependency("anne_dice", .{ .target = target.resolved, .optimize = target.optimize }).module("anne_dice");
    //const nds_mod = b.dependency("anne_nds_dev", .{.target = target.resolved, .optimize = target.optimize}).module("anne_nds_dev");
    const nds_mod = b.dependency("anne_nds_dev", .{ .optimize = target.optimize }).module("anne_nds_dev");
    const log = b.dependency("anne_log", .{ .target = target.resolved, .optimize = target.optimize }).module("anne_log");
    // TODO fix
    //const bzip2 = b.dependency("anne_bzip2", .{.target = target.resolved, .optimize = target.optimize}).module("anne_bzip2");

    const deps: []const std.Build.Module.Import = &.{
        .{ .name = "benchmark", .module = bench },
        .{ .name = "table", .module = table },
        .{ .name = "uuid", .module = uuid },
        .{ .name = "dice", .module = dice },
        .{ .name = "nds", .module = nds_mod },
        .{ .name = "log", .module = log },
        //.{ .name = "bzip2", .module = bzip2 },
    };

    const mod = b.addModule("kitsubit", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target.resolved,
        .optimize = target.optimize,
        .imports = deps,
    });

    // TODO fix dupe
    const example_deps: []const std.Build.Module.Import = &.{
        .{ .name = "benchmark", .module = bench },
        .{ .name = "table", .module = table },
        .{ .name = "uuid", .module = uuid },
        .{ .name = "dice", .module = dice },
        .{ .name = "nds", .module = nds_mod },
        .{ .name = "log", .module = log },
        //.{ .name = "bzip2", .module = bzip2 },
        .{ .name = "kitsubit", .module = mod },
    };

    if (nds) {
        const compile_nds = compileNds(b, .{
            .name = "kitsubit",
            .optimize = target.optimize,
            .root_file = b.path("examples/terminal/main.zig"),
            .imports = example_deps,
        });
        b.default_step.dependOn(&compile_nds.step);

        const run_emulator_cmd = b.addSystemCommand(&.{ emulator_nds, "zig-out/bin/kitsubit.nds" });
        run_emulator_cmd.step.dependOn(&compile_nds.step);

        const run_step = b.step("run", "Run in an emulator (melonDS)");
        run_step.dependOn(&run_emulator_cmd.step);
    }

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

fn resolveTarget(b: *std.Build, optimize: std.builtin.OptimizeMode, nds: bool) Target {
    var engine_target: EngineTarget = .native;
    if (nds) {
        engine_target = .nds;
    }

    const resolved_target = switch (engine_target) {
        .native => b.standardTargetOptions(.{}),
        // TODO replace by import
        .nds => b.resolveTargetQuery(.{
            .cpu_arch = .thumb,
            .os_tag = .freestanding,
            .cpu_model = .{ .explicit = &std.Target.arm.cpu.arm946e_s },
        }),
    };

    return .{
        .named = engine_target,
        .resolved = resolved_target,
        .optimize = optimize,
    };
}
