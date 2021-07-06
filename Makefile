luastaticlib = /mingw64/lib/libluajit-5.1.a
luaincludedir = /mingw64/include/luajit-2.1/
all:
	test -f mdlinspect.lua || ln dist/lua/includes/modules/mdlinspect.lua
	test -f binfuncs.lua || ln dist/lua/includes/modules/binfuncs.lua
	luajit luastatic.lua \
	  init.lua \
	  mdlinspect.lua minigcompat.lua binfuncs.lua vstruct/lexer.lua vstruct/ast.lua vstruct/ast/*.lua vstruct/cursor.lua vstruct/io.lua vstruct/io/*.lua vstruct/init.lua  vstruct/api.lua \
	  $(luastaticlib) \
	  -I$(luaincludedir) -o reslister.exe
