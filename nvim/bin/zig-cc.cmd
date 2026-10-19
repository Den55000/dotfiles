@echo off
rem C compiler for tree-sitter on Windows (init.lua points $CC here when there's
rem no MSVC). tree-sitter asks for the MSVC target, which zig spells differently
rem and which would need Visual Studio's libraries; build against mingw instead.
set "args=%*"
set "args=%args:x86_64-pc-windows-msvc=x86_64-windows-gnu%"
zig cc %args%
