package = "cffi-lua"
version = "0.2.3-1"
source = {
    url = "git+https://github.com/q66/cffi-lua",
    tag = "v0.2.3"
}
description = {
    summary = "A portable C FFI for Lua 5.1+",
    detailed = [[
        This is a portable C FFI for Lua, based on libffi. It aims to be
        mostly compatible with the LuaJIT FFI, but written from scratch
        and compatible with different systems and CPU architectures.

        It doesn't aim to provide strictly only what LuaJIT FFI provides;
        there is also support for features from newer Lua versions as well
        as various other extensions, both in its API and in its language
        support.
    ]],
    homepage = "https://github.com/q66/cffi-lua",
    license = "MIT"
}
dependencies = {
    "lua >= 5.1"
}
external_dependencies = {
    MESON = { program = "meson" },
}
build = {
    type = "command",
    build_command = [[\
        LUA="$(LUA)" CC="$(CC)" LD="$(LD)" \
        CFLAGS='$(CFLAGS) -I$(LUA_INCDIR)' \
        PREFIX="$(PREFIX)" LIBDIR="$(LIBDIR)" \
        sh ./luarocks/build.sh build
    ]],
    install_command = [[\
        LUA="$(LUA)" CC="$(CC)" LD="$(LD)" \
        CFLAGS='$(CFLAGS) -I$(LUA_INCDIR)' \
        PREFIX="$(PREFIX)" LIBDIR="$(LIBDIR)" \
        sh ./luarocks/build.sh install
    ]],
}
