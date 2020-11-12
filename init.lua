-- reslister --

--local lfs = require'lfs'

-- uncomment for debug
--if not pcall(require,'vstruct') and not package.path:find([[;.\?\init.lua]],1,true) then
--	package.path=package.path..[[;.\?\init.lua]]
--end


require'minigcompat'
require'binfuncs'
require'mdlinspect'

local function wrap(ok, ...)
	if ok then return ... end
	print""
	print("FAIL", ...)
end

local function SAFE(func, ...)
	return wrap(xpcall(func, debug.traceback, ...))
end

local fmt_bspzip = false
local t = {...}
for i=#t,1,-1 do
	if t[i]:lower()=="--format=bspzip" then
		table.remove(t,i)
		fmt_bspzip = true
	end
end
local file, respath,out = unpack(t)

if not file and not respath then
	print[[Usage: reslister [--format=bspzip] "c:\mymap\map.vmf" "c:\mymap\resources" "c:\mymap\reslist.txt"]]
	return
end
out = out or [[reslist.txt]]

local function respath_has(relpath)
	local p = ("/%s"):format(relpath)
	p=p:gsub("[%\\%/][%\\%/]?","%/")
	local p = ("%s%s"):format(respath, p)
	--print(p)
	if p:find"mapdata/sprit" then error(p) end
	if os.rename(p, p) then return p end
end

local processors = {}
local reslist = {}

function _G.RESADD(path)
	path=path:gsub("[%\\%/][%\\%/]?","%/")
	path=path:lower()
	reslist[path] = true
end

local parsers = {}
local warned = {}

local function PARSE(path)
	local ext = path:match'[^%.]+$'
	local func = parsers[ext:lower()]

	if func then
		func(path)
	else
		if not warned[ext] then
			warned[ext] = true
			print("did not parse", ext)
		end
	end
end
-- processors for map format entries --
local function dogeneric(path)
	local full = respath_has(path)

	if full then
		RESADD(path)
		PARSE(full)
		return true
	end
end

-- parsers for different filetypes --
local vmt_key_whitelist = {}

local w= {'basetexture','basetexture2',
'phongexponenttexture','texture', 'detail',
 'blendmodulatetexture', 'bumpmap', 
 'normalmap', 'parallaxmap', 'heightmap', 
 'selfillummask', 'lightwarptexture', 
 'envmap', 'envmapmask', 'displacementmap', 
 'reflecttexture', 'refracttexture',
 'refracttinttexture', 'dudvmap', 
 'bottommaterial', 'underwateroverlay'}
 
for k, v in next, w do
	vmt_key_whitelist[v] = true
end

local function vmtlineparse(l)
	local L = l
	
	-- keys we are interested in start with $...
	local pos = l:find("$", 1, true)
	if not pos then return end
	
	-- ...  but not all keys start with $
	if l:sub(1, pos):find"[a-zA-Z]" then return end
	
	-- fuzzy comments
	local commentpos = l:find("//", 1, true)
	if commentpos and commentpos > pos then return end
	
	-- keys we are interested in start with this pattern
	local _, stoppos, key = l:find("([a-zA-Z]+)", pos + 1)

	if not key then
		print("???", l)

		return
	end

	key = key:lower()
	if not vmt_key_whitelist[key] then return end
	
	-- cleanup rest of line
	l = l:sub(stoppos + 1, -1):gsub("[\r\n]*$", ''):gsub("^[\t%s]+", ""):gsub("[\t%s]+$", "")
	
	-- attempt finding value using various patterns
	local val = l:match([["%s%s?"([^"]+)"]]) or l:match'"([^"]+)"%s*$'
	val = val or l
	assert(not val:find('"', 1, true))

	--print("process",val)
	if key:find("material", 1, true) then
		processors.material(val)
	else
		processors.texture(val)
	end
	
	
end

function parsers:vtf()end -- no
function parsers:phy()end
function parsers:vvd()end
function parsers:vtx()end

function parsers:vmt()
	for l in io.lines(self) do
		vmtlineparse(l)
	end
end

local function parse_mdl(f, fp)
	local mdl, err = mdlinspect.Open(f)

	if not mdl then
		print("FAIL", fp, err)
	end

	mdl:ParseHeader()
	local mdls = mdl:IncludedModels()

	for k, v in next, mdls do
		print("NOT IMPLEMENTED", k, v)
	end

	local materials = mdl:Textures()
	local paths = mdl:TextureDirs()
	for _,matdat in next,materials do
		local material = matdat[1]
		local found
		for _,path in next,paths do
			if dogeneric(("materials/%s/%s.vmt"):format(path,material)) or dogeneric(("materials/%s/%s.vtf"):format(path,material)) then
				--print("FOUND",path,material)
				found=true
				break
			end
			
		end
		if not found then
			print("notfound",fp,material)
		end
	end
	
end

function parsers:mdl()
	local f = assert(io.open(self, 'rb'))
	SAFE(parse_mdl, f, self)
	f:close()
end


function processors:material()
	local path = ("materials/%s.vmt"):format(self)
	if dogeneric(path) then return end
	assert(not self:lower():find("%.[a-z][a-z][a-z]$",-4),self)
end

function processors:texture()
	if dogeneric("materials/"..self) then return end
	if not self:lower():find("%.[a-z][a-z][a-z]$",-4) then
		local gotvmt = dogeneric(("materials/%s.vmt"):format(self))
		local gotvtf = dogeneric(("materials/%s.vtf"):format(self))
		if gotvmt or gotvtf then return end
		
		if dogeneric(("materials/%s.jpg"):format(self)) then return end
		if dogeneric(("materials/%s.png"):format(self)) then return end
	end
end

function processors:message()
	if self:find"%.[a-zA-Z][a-zA-Z][a-zA-Z]$" then
		if dogeneric(("sound/%s"):format(self)) then return end
	else
		local found = dogeneric(("sound/%s.wav"):format(self)) or dogeneric(("sound/%s.mp3"):format(self)) or dogeneric(("sound/%s.ogg"):format(self))
		if found then return end
	end
end

--TODO?? find .wav/.ogg/.mp3 instead
processors.noise1 = processors.message
processors.noise2 = processors.message
processors.soundcloseoverride = processors.message
processors.soundmoveoverride = processors.message
processors.stopsound = processors.message
processors.startsound = processors.message
processors.movesound = processors.message

function processors:model()
	
	-- TODO: may be vmf and .spr, otherwise always mdl and models/
	local normal = self:find'^models/.*%.mdl$'
	if normal then
		
		local path = self
		if dogeneric(path) then
			path = path:sub(1,-5)
			dogeneric(path..'.phy')
			dogeneric(path..'.dx80.vtx')
			dogeneric(path..'.dx90.vtx')
			dogeneric(path..'.sw.vtx')
			dogeneric(path..'.vvd')
		end
		
	else
		assert(not self:lower():find("%.mdl$"))
		if dogeneric("materials/"..self) then
			print("but okay",self)
			return
		end
		
	end
end

local res = {}
local function parsevmfline(l)
	local pos = l:find('" "', 3, true)

	if not pos then return end
	local left = l:sub(2, pos):lower()

	if not (left:find("material", 1, true) or left:find("texture", 1, true) or left:find("model", 1, true) or left:find("sound", 1, true) or left:find("message", 1, true)) then
		return
	end

	local right = l:sub(pos + 3, -1)
	local firstquote = left:find('"', 1, true)
	local key = left:sub(firstquote + 1, #left - 1)
	local val = right:gsub('"[^"]*$', '')
	--print(key,val)
	local t = res[key]

	if not t then
		t = {}
		res[key] = t
	end

	t[val:lower()] = true
end

local function process_found()
	for restype, paths in next, res do
		restype = restype:lower()

		local processor_func = processors[restype]

		if processor_func then
			for path, _ in next, paths do
				processor_func(path)
			end
		end
	end
end

local function main()
	print"Parsing VMF"

	for l in io.lines(file) do
		parsevmfline(l)
	end

	print"Processing lists..."

	process_found()

	print"Writing list..."
	local t = {}
	for k, v in next, reslist do
		t[#t+1] = k
	end
	
	print(#t, "resources")
	
	table.sort(t)
	
	local f = io.open(out,'wb')
	for k, v in next, t do
		f:write(v..'\n')
		if fmt_bspzip then
			f:write(v..'\n')
		end
	end
	f:close()
	print"Calculating sizes..."
	local szsum = 0
	for path, _ in next, reslist do
		local f = assert(io.open(respath_has(path),'rb'))
		local sz = f:seek("end")
		szsum = szsum + sz
		reslist[path]=sz
		f:close()
	end
	print("Size:",math.floor(szsum/1000/1000),"MB uncompressed")
	
	local t = {}
	for k,v in next,reslist do
		t[#t+1] = {k,v}
	end
	table.sort(t,function(a,b) return a[2]<b[2] end)
	print"Top 10: "
	for i=#t,math.max(1,#t-10),-1 do
		print("",math.floor(t[#t][2]/1000),"KB",t[i][1])
	end

end

main()
