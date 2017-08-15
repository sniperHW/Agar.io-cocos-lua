local M = {}
M.stars = {}

function M.OnStars(stars)
	if bit then
		for k,v in pairs(stars) do

		end		
	else
		for k,v in pairs(stars) do

		end
	end
end

function M.Render(scene,drawer)
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