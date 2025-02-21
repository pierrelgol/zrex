const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.addModule("zrex", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zrex",
        .root_module = lib_mod,
        .use_llvm = false,
        .use_lld = false,
    });

    b.installArtifact(lib);

    const lib_check = b.addLibrary(.{
        .linkage = .static,
        .name = "zrex",
        .root_module = lib_mod,
        .use_llvm = false,
        .use_lld = false,
    });

    const check_step = b.step("check", "zls tooling support");
    check_step.dependOn(&lib_check.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
