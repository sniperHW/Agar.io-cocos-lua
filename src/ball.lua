local M = {}

local ball = {}
ball.__index = ball

function M.new(userID,ballID,pos,color,r)
	local o = {}
	o = setmetatable(o,ball)
	o.userID = userID
	o.id = ballID
	o.pos = {x = pos.x,y = pos.y}
	o.color = color
	o.r = r
	return o
end

function ball:Update(elapse)

end

return M
