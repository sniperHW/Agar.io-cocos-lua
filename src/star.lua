local config = require("config")
local M = {}
M.stars = {}

local function newStar(starID)
	local starConfig = config.stars[starID]
	local color = config.colors[starConfig.color]
	local star = {}
	star.id = starID
	star.pos = {x = starConfig.x , y = starConfig.y}
	star.color = cc.c4f(color[1],color[2],color[3],color[4])
	star.r = 2
	return star
end

function M.OnStars(event)
	for k,v in pairs(event.stars) do
		local i = k - 1
		for j = 0,31 do
			if bit.band(bit.lshift(1,j),v) ~= 0 then
				local starID = i * 32 + j + 1
				M.stars[starID] = newStar(starID)
			end
		end
	end		

--[[ lua53
	for k,v in pairs(stars) do
		local i = k - 1
		for j = 0,31 do
			if (1 << j) > 0 then
				local starID = i * 32 + j + 1
				M.stars[starID] = newStar(starID)
			end
		end			
	end
]]	

end

function M.OnStarDead(event)	
	for k,v in pairs(event.stars) do
		M.stars[v] = nil
	end
	--M.stars[event.id] = nil
end

function M.OnStarRelive(event)
	for k,v in pairs(event.stars) do
		M.stars[v] = newStar(v)
	end
end

function M.Render(scene)
	for k,v in pairs(M.stars) do
		local viewPortPos = scene:world2ViewPort(v.pos)
        if scene:isInViewPort(viewPortPos) then
        	local screenPos = scene:viewPort2Screen(viewPortPos)
        	--只有在屏幕内的星星才渲染
        	scene.drawer:drawSolidCircle(cc.p(screenPos.x ,screenPos.y), v.r * scene.scaleFactor, math.pi/2, 50, 1.0, 1.0, v.color)
        end
	end
end

return M