@echo off
set PATH=%~dp0tools;%PATH%
set LUAROCKS_SYSCONFDIR=%~dp0../lib/luarocks/rocks-5.1
"%~dp0luajit" "%~dp0../lib/luarocks/rocks-5.1/luarocks/3.9.2-1/bin/luarocks.lua" config --scope system home_tree "%~dp0.." > nul 2>&1
"%~dp0luajit" "%~dp0../lib/luarocks/rocks-5.1/luarocks/3.9.2-1/bin/luarocks-admin.lua" %*
