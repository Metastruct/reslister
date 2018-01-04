# Msys2 mingw64.exe http://www.msys2.org/
all:
	test -f mdlinspect.lua || ln dist/lua/includes/modules/mdlinspect.lua
	test -f binfuncs.lua || ln dist/lua/includes/modules/binfuncs.lua
	luajit luastatic.lua init.lua mdlinspect.lua minigcompat.lua binfuncs.lua vstruct/lexer.lua vstruct/cursor.lua vstruct/io.lua vstruct/init.lua vstruct/io/f.lua vstruct/api.lua /mingw64/lib/libluajit-5.1.a -I/mingw64/include/luajit-2.0/ -o reslister.exe
