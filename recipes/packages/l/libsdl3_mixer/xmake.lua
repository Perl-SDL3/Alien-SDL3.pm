-- Local override of the xmake-repo package recipe for libsdl3_mixer.
--
-- Deviations from packages/l/libsdl3_mixer/xmake.lua in xmake-repo:
--   * adds a Windows/vcpkg extsource plus an on_fetch gate that refuses it
--     unless the system core passes the core recipe's own version gate.
-- Keep this file in sync with the upstream recipe when bumping versions.
--
package("libsdl3_mixer")
    set_homepage("https://github.com/libsdl-org/SDL_mixer")
    set_description("An audio mixer that supports various file formats for Simple Directmedia Layer.")
    set_license("zlib")

    if is_plat("mingw") and is_subhost("msys") then
        add_extsources("pacman::sdl3-mixer")
    elseif is_plat("linux") then
        add_extsources("pacman::sdl3_mixer", "apt::libsdl3-mixer-dev")
    elseif is_plat("macosx") then
        add_extsources("brew::sdl3_mixer")
    elseif is_plat("windows") then
        add_extsources("vcpkg::sdl3-mixer")
    end

    -- Windows/vcpkg only: never take vcpkg's extension while the system core
    -- fails the core recipe's own gate -- that is how the family ends up half
    -- system, half source-built, with two SDL3 ABIs in one link. This mirrors
    -- recipes/packages/l/libsdl3/xmake.lua on_fetch: vcpkg is the only system
    -- source on Windows, and the version floor is read from the same port
    -- revision format (keep "3.4.18" in sync with _MIN_SYSTEM_VERSION there).
    -- nil lets xmake's normal candidates run; false disables the system path
    -- outright -- @see core/package/package.lua _fetch_library.
    on_fetch(function (self, opt)
        if not opt.system or not self:is_plat("windows") then
            return
        end
        local semver = import("core.base.semver")
        local core = self:find_package("vcpkg::sdl3", {system = true})
        if not core then
            -- The core is going to come from source here; keep the extension
            -- with it rather than linking it against vcpkg's SDL3.
            return false
        end
        local comparable = (core.version or ""):gsub("%-%d+$", "")
        local satisfies = try {
            function () return semver.satisfies(comparable, ">=3.4.18") end
        }
        if not satisfies then
            print(string.format("libsdl3_mixer: vcpkg SDL3 core %s is older than 3.4.18, building from source",
                  core.version or "of unknown version"))
            return false
        end
        return self:find_package("vcpkg::sdl3-mixer", {system = true})
    end)

    add_urls("https://www.libsdl.org/projects/SDL_mixer/release/SDL3_mixer-$(version).zip",
             "https://github.com/libsdl-org/SDL_mixer/releases/download/release-$(version)/SDL3_mixer-$(version).zip", { alias = "archive" })
    add_urls("https://github.com/libsdl-org/SDL_mixer.git", {alias = "github", submodules = false})

    add_versions("archive:3.2.2", "09bb145c399231390b37024aeeeba82c0a105471184a231a5ce3993747ca9308")
    add_versions("archive:3.2.4", "bbf0173861d5ee66555605435d4f423261d228649cb03dcb6cf3d24063683625")

    add_versions("github:3.2.2", "release-3.2.2")
    add_versions("github:3.2.4", "release-3.2.4")

    add_deps("cmake")

    on_load(function (package)
        package:add("deps", "libsdl3", { configs = { shared = package:config("shared") }})
    end)

    on_install(function (package)
        local configs = {"-DSDLMIXER_TESTS=OFF", "-DSDLMIXER_EXAMPLES=OFF", "-DSDLMIXER_VENDORED=OFF"}
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:is_debug() and "Debug" or "Release"))
        table.insert(configs, "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))
        import("package.tools.cmake").install(package, configs)
    end)

    on_test(function (package)
        assert(package:has_cfuncs("MIX_Version", {includes = "SDL3_mixer/SDL_mixer.h"}))
    end)
