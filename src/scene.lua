local M = {}

local scene = {}
scene.__index = scene


M.visibleSize = cc.Director:getInstance():getVisibleSize()
M.origin = cc.Director:getInstance():getVisibleOrigin()

--场景大小
M.width = 10000
M.height = 10000


M.New = function ()
	local o = {}   
	o = setmetatable(o, scene)
	return o
end

function scene:viewPort2Screen(viewPortPos)
	viewPortPos.x = viewPortPos.x * self.scaleFactor + M.origin.x
	viewPortPos.y = viewPortPos.y * self.scaleFactor + M.origin.y
	return viewPortPos
end

function scene:world2ViewPort(worldPos)
	local screenPos = {}
	screenPos.x = worldPos.x - self.viewPort.leftBottom.x
	screenPos.y = worldPos.y - self.viewPort.leftBottom.y
	return screenPos
end

function scene:isInViewPort(viewPortPos)
	if viewPortPos.x < 0 then
		return false
	end

	if viewPortPos.y < 0 then
		return false
	end

	if viewPortPos.x > self.viewPort.width then
		return false
	end

	if viewPortPos.y > self.viewPort.height then
		return false
	end

	return true	
end


--根据ball的坐标,更新屏幕左下角在世界坐标的位置
function scene:updateViewPortLeftBottom()
	local leftBottom = {}
	leftBottom.x = self.centralPos.x - self.viewPort.width/2
	leftBottom.y = self.centralPos.y - self.viewPort.height/2

	--根据边界修正坐标

	if leftBottom.x < 0 then
		leftBottom.x = 0
	end

	if leftBottom.y < 0 then
		leftBottom.y = 0
	end

	if leftBottom.x + self.viewPort.width > M.width then
		leftBottom.x = M.width - self.viewPort.width
	end

	if leftBottom.y + self.viewPort.height > M.height then
		leftBottom.y = M.height - self.viewPort.height
	end	

	self.viewPort.leftBottom = leftBottom

end

function scene:setViewPort(width,height)
    self.viewPort = self.viewPort or {}	
    self.viewPort.width = width
    self.viewPort.height = height
    self.scaleFactor = M.visibleSize.width/self.viewPort.width
    cclog("scaleFactor:%f",self.scaleFactor)
end

function scene:Init(drawer)
	cclog("(%d, %d, %d, %d)", M.origin.x, M.origin.y, M.visibleSize.width, M.visibleSize.height)
	self.drawer = drawer
	ball = {}
    ball.color = cc.c4f(math.random(1,100)/100,math.random(1,100)/100,math.random(1,100)/100,1)
    --球出生在场景中心	
    ball.pos = {x = M.width/2,y = M.width/2}
    ball.r = 60
    ball.dir = nil
    self.ball = ball
    self.stars = {}
    for i=1,2048 do
        local star = {}
        star.color = cc.c4f(math.random(1,100)/100,math.random(1,100)/100,math.random(1,100)/100,1)
        star.pos = {x = math.random(1,M.width),y = math.random(1,M.height)}
        star.r = 2
        table.insert(self.stars,star)           
    end
    self.centralPos = self.ball.pos
    self:setViewPort(M.visibleSize.width*1.5,M.visibleSize.height*1.5)    
    self:updateViewPortLeftBottom()
	
	return self
end

function scene:UpdateCentralPos()
	self.centralPos = self.ball.pos
end

function scene:Update(elapse)
    if self.ball.dir then
        self.ball.pos.x = self.ball.pos.x + 5 * self.ball.dir.x
        self.ball.pos.y = self.ball.pos.y + 5 * self.ball.dir.y
        if self.ball.pos.x > M.width - self.ball.r then
            self.ball.pos.x = M.width - self.ball.r
        end

        if self.ball.pos.x < self.ball.r then
            self.ball.pos.x = self.ball.r
        end

        if self.ball.pos.y > M.height - self.ball.r then
            self.ball.pos.y = M.height - self.ball.r
        end

        if self.ball.pos.y < self.ball.r then
            self.ball.pos.y = self.ball.r
        end
        self:UpdateCentralPos()
        self:updateViewPortLeftBottom()
    end	
end

function scene:Render()
    self.drawer:clear()
    for k,v in pairs(self.stars) do
        local viewPortPos = self:world2ViewPort(v.pos)
        if self:isInViewPort(viewPortPos) then
        	local screenPos = self:viewPort2Screen(viewPortPos)
        	--只有在屏幕内的星星才渲染
        	self.drawer:drawSolidCircle(cc.p(screenPos.x ,screenPos.y), v.r * self.scaleFactor, math.pi/2, 50, 1.0, 1.0, v.color)
        end
    end

    local screenPos = self:viewPort2Screen(self:world2ViewPort(self.ball.pos))
    self.drawer:drawSolidCircle(cc.p(screenPos.x ,screenPos.y), self.ball.r * self.scaleFactor, math.pi/2, 50, 1.0, 1.0, self.ball.color)
end

function scene:DispatchEvent(event)
	self.ball.dir = event
end


return M