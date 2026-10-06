const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSafe,
    });

    const default_export_linkage: std.builtin.GlobalLinkage =
        if (target.result.os.tag == .emscripten) .weak else .strong;
    const export_linkage = b.option(std.builtin.GlobalLinkage, "export_linkage", "Global linkage for exported OpenGL C symbols") orelse
        default_export_linkage;

    const build_options = b.addOptions();
    build_options.addOption(std.meta.Tag(std.builtin.GlobalLinkage), "linkage", @intFromEnum(export_linkage));

    const root = b.addModule("root", .{
        .root_source_file = b.path("src/zopengl.zig"),
    });
    root.addOptions("build_options", build_options);

    {
        const test_step = b.step("test", "Run zopengl tests");

        const tests = b.addTest(.{
            .name = "zopengl-tests",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/zopengl.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        tests.root_module.addOptions("build_options", build_options);
        b.installArtifact(tests);

        test_step.dependOn(&b.addRunArtifact(tests).step);
    }

    const lib = b.addLibrary(.{
        .name = "zopengl",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zopengl.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib.root_module.addOptions("build_options", build_options);
    _ = b.installArtifact(lib);

    // Emit the autodoc bundle for the library module only. This mirrors the
    // options of the library above, so the documented API is the loader
    // itself rather than this build script.
    {
        const docs_step = b.step("docs", "Generate API documentation");

        const docs_obj = b.addObject(.{
            .name = "zopengl",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/zopengl.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        docs_obj.root_module.addOptions("build_options", build_options);

        const install_docs = b.addInstallDirectory(.{
            .source_dir = docs_obj.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });

        docs_step.dependOn(&install_docs.step);
        docs_step.dependOn(&docs_obj.step);
    }
}
