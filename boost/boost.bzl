load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

hdrs_patterns = [
    "boost/%s.h",
    "boost/%s_fwd.h",
    "boost/%s.hpp",
    "boost/%s_fwd.hpp",
    "boost/%s/**/*.hpp",
    "boost/%s/**/*.ipp",
    "boost/%s/**/*.h",
    "libs/%s/src/*.ipp",
]

srcs_patterns = [
    "libs/%s/src/*.cpp",
    "libs/%s/src/*.hpp",
]

# Building boost results in many warnings for unused values. Downstream users
# won't be interested, so just disable the warning.
default_copts = select({
    "@platforms//os:windows": [],
    "//conditions:default": ["-Wno-unused"],
})

default_defines = select({
    ":windows_x86_64": ["BOOST_ALL_NO_LIB"],  # Turn auto_link off in MSVC compiler
    "//conditions:default": [],
})

def srcs_list(library_name, exclude):
    return native.glob(
        [p % (library_name,) for p in srcs_patterns],
        exclude = exclude,
        allow_empty = True,
    )

def hdr_list(library_name, exclude = []):
    return native.glob([p % (library_name,) for p in hdrs_patterns], exclude = exclude, allow_empty = True)

def boost_library(
        name,
        boost_name = None,
        defines = None,
        local_defines = None,
        includes = None,
        hdrs = None,
        srcs = None,
        deps = None,
        copts = None,
        exclude_src = [],
        exclude_hdr = [],
        linkopts = None,
        linkstatic = None,
        namespace = "boost",
        visibility = ["//visibility:public"]):
    if boost_name == None:
        boost_name = name

    if defines == None:
        defines = []

    if local_defines == None:
        local_defines = []

    if includes == None:
        includes = []

    if hdrs == None:
        hdrs = []

    if srcs == None:
        srcs = []

    if deps == None:
        deps = []

    if copts == None:
        copts = []

    if linkopts == None:
        linkopts = []

    native.alias(
        name = name,
        actual = ":" + namespace + "_" + name,
        visibility = visibility,
    )

    return native.cc_library(
        name = namespace + "_" + name,
        visibility = visibility,
        defines = default_defines + defines,
        includes = ["."] + includes,
        local_defines = local_defines,
        hdrs = hdr_list(boost_name, exclude_hdr) + hdrs,
        srcs = srcs_list(boost_name, exclude_src) + srcs,
        deps = deps,
        copts = default_copts + copts,
        linkopts = linkopts,
        linkstatic = linkstatic,
        licenses = ["notice"],
    )

# Some boost libraries are not safe to use as dynamic libraries unless a
# BOOST_*_DYN_LINK define is set when they are compiled and included, notably
# Boost.Test. When the define is set, the libraries are not safe to use
# statically. This is an attempt to work around that. We build an explicit .so
# with cc_binary's linkshared=True and then we reimport it as a C++ library and
# expose it as a boost_library.

def boost_so_library(
        name,
        boost_name = None,
        defines = [],
        srcs = [],
        deps = [],
        copts = [],
        exclude_src = [],
        exclude_hdr = []):
    if boost_name == None:
        boost_name = name

    native.cc_binary(
        name = "lib_internal_%s" % name,
        visibility = ["//visibility:private"],
        srcs = hdr_list(boost_name, exclude_hdr) + srcs_list(boost_name, exclude_src) + srcs,
        deps = deps,
        copts = default_copts + copts,
        defines = default_defines + defines,
        linkshared = True,
        licenses = ["notice"],
    )
    native.filegroup(
        name = "%s_dll_interface_file" % name,
        srcs = [":lib_internal_%s" % name],
        output_group = "interface_library",
        visibility = ["//visibility:private"],
    )
    native.cc_import(
        name = "_imported_%s" % name,
        shared_library = ":lib_internal_%s" % name,
        interface_library = ":%s_dll_interface_file" % name,
        visibility = ["//visibility:private"],
    )
    return boost_library(
        name = name,
        boost_name = boost_name,
        defines = defines,
        exclude_hdr = exclude_hdr,
        exclude_src = native.glob([
            "libs/%s/**" % boost_name,
        ]),
        deps = deps + [":_imported_%s" % name],
    )

def boost_deps():
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "74d544d96f4a5bb630d465ca8bbcfe231e3594e5aae57e1edbf17a6eb3ca2506",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "net_zlib_zlib",
        build_file = "@com_github_bitstothings_rules_boost//:BUILD.zlib",
        #sha256 = "91844808532e5ce316b3c010929493c0244f3d37593afd6de04f71821d5136d9",
        strip_prefix = "zlib-1.2.13",
        urls = [
            "https://mirror.bazel.build/zlib.net/zlib-1.2.13.tar.gz",
            "https://zlib.net/zlib-1.2.13.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "org_bzip_bzip2",
        build_file = "@com_github_bitstothings_rules_boost//:BUILD.bzip2",
        sha256 = "ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269",
        strip_prefix = "bzip2-1.0.8",
        urls = [
            "https://mirror.bazel.build/sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz",
            "https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz",
        ]
    )

    SOURCEFORGE_MIRRORS = ["cfhcable", "superb-sea2", "cytranet", "iweb", "gigenet", "ayera", "astuteinternet", "pilotfiber", "svwh"]

    maybe(
        http_archive,
        name = "org_lzma_lzma",
        build_file = "@com_github_bitstothings_rules_boost//:BUILD.lzma",
        sha256 = "06327c2ddc81e126a6d9a78b0be5014b976a2c0832f492dcfc4755d7facf6d33",
        strip_prefix = "xz-5.2.7",
        urls = [
            "https://%s.dl.sourceforge.net/project/lzmautils/xz-5.2.7.tar.gz" % m
            for m in SOURCEFORGE_MIRRORS
        ],
    )

    maybe(
        http_archive,
        name = "com_github_facebook_zstd",
        build_file = "@com_github_bitstothings_rules_boost//:BUILD.zstd",
        sha256 = "e28b2f2ed5710ea0d3a1ecac3f6a947a016b972b9dd30242369010e5f53d7002",
        strip_prefix = "zstd-1.5.1",
        urls = [
            "https://github.com/facebook/zstd/releases/download/v1.5.1/zstd-1.5.1.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "boost",
        build_file = "@com_github_bitstothings_rules_boost//:BUILD.boost",
        patch_cmds = ["rm -f doc/pdf/BUILD"],
        patch_cmds_win = ["Remove-Item -Force doc/pdf/BUILD"],
        sha256 = "4b2136f98bdd1f5857f1c3dea9ac2018effe65286cf251534b6ae20cc45e1847",
        strip_prefix = "boost_1_80_0",
        urls = [
            "https://mirror.bazel.build/boostorg.jfrog.io/artifactory/main/release/1.80.0/source/boost_1_80_0.tar.gz",
            "https://boostorg.jfrog.io/artifactory/main/release/1.80.0/source/boost_1_80_0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "openssl",
        sha256 = "6f640262999cd1fb33cf705922e453e835d2d20f3f06fe0d77f6426c19257308",
        strip_prefix = "boringssl-fc44652a42b396e1645d5e72aba053349992136a",
        url = "https://github.com/google/boringssl/archive/fc44652a42b396e1645d5e72aba053349992136a.tar.gz",
    )
