local net = require("net")
local ball = require("ball")
local config = require("config")
local star = require("star")
local M = {}

local scene = {}
scene.__index = scene

M.visibleSize = cc.Director:getInstance():getVisibleSize()
M.origin = cc.Director:getInstance():getVisibleOrigin()
M.delayTick = 120

--场景大小
M.width = config.mapWidth
M.height = config.mapWidth

M.viewBounderyBottomLeft = {
	x = 0 - M.visibleSize.width/2,
	y = 0 - M.visibleSize.height/2
}

M.viewBounderyTopRight = {
	x = M.width + M.visibleSize.width/2,
	y = M.height + M.visibleSize.height/2
}


M.New = function ()
	local o = {}   
	o = setmetatable(o, scene)
	return o
end

--返回通过本地tick估算的serverTick
function scene:GetServerTick()
	return self.gameTick --+ self.serverTickDelta
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

	if leftBottom.x < M.viewBounderyBottomLeft.x then
		leftBottom.x = M.viewBounderyBottomLeft.x
	end

	if leftBottom.y < M.viewBounderyBottomLeft.y  then
		leftBottom.y = M.viewBounderyBottomLeft.y
	end

	if leftBottom.x + self.viewPort.width > M.viewBounderyTopRight.x then
		leftBottom.x = M.viewBounderyTopRight.x - self.viewPort.width--M.width - self.viewPort.width + M.visibleSize.width/2
	end

	if leftBottom.y + self.viewPort.height > M.viewBounderyTopRight.y then
		leftBottom.y = M.viewBounderyTopRight.y - self.viewPort.height--M.height - self.viewPort.height + M.visibleSize.height/2
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
	self.serverTickDelta = 0
	self.gameTick = 0
	self.lastTick = net.GetSysTick()
	self.drawer = drawer
    self.balls = {}
    self.stars = {}
    self.delayMsgQue = {}
    for i=1,2048 do
        local star = {}
        star.color = cc.c4f(math.random(1,100)/100,math.random(1,100)/100,math.random(1,100)/100,1)
        star.pos = {x = math.random(1,M.width),y = math.random(1,M.height)}
        star.r = 2
        table.insert(self.stars,star)           
    end
    self.centralPos = {x = M.width/2, y = M.height/2 }
    self:setViewPort(M.visibleSize.width,M.visibleSize.height)    
    self:updateViewPortLeftBottom()
	
	return self
end

function scene:Update()

	local nowTick = net.GetSysTick()

	if self.lastFixTime then
		if nowTick - self.lastFixTime > 1000 then
			local wpk = net.NewWPacket()
    		wpk:WriteTable({cmd="FixTime",clientTick=nowTick})
    		send2Server(wpk)
			self.lastFixTime = nowTick
		end
	end

	local elapse = nowTick - self.lastTick
	self.gameTick = self.gameTick + elapse
	self.lastTick = nowTick
	self:processDelayMsg()
	local ownBallCount = 0
	local cx = 0
	local cy = 0
	for k,v in pairs(self.balls) do
		v:Update(elapse)
		if v.userID == userID then
			cx = cx + v.pos.x
			cy = cy + v.pos.y
			ownBallCount = ownBallCount + 1
		end
	end
	if ownBallCount > 0 then
		self.centralPos.x = cx/ownBallCount --(self.centralPos.x + cx) / 2
		self.centralPos.y = cy/ownBallCount --(self.centralPos.y + cy) / 2
		self:updateViewPortLeftBottom()
	end
end

function scene:Render()
    self.drawer:clear()
    star.Render(self)
    --[[for k,v in pairs(self.stars) do
        local viewPortPos = self:world2ViewPort(v.pos)
        if self:isInViewPort(viewPortPos) then
        	local screenPos = self:viewPort2Screen(viewPortPos)
        	--只有在屏幕内的星星才渲染
        	self.drawer:drawSolidCircle(cc.p(screenPos.x ,screenPos.y), v.r * self.scaleFactor, math.pi/2, 50, 1.0, 1.0, v.color)
        end
    end]]--

    for k,v in pairs(self.balls) do
    	local screenPos = self:viewPort2Screen(self:world2ViewPort(v.pos))
    	self.drawer:drawSolidCircle(cc.p(screenPos.x ,screenPos.y), v.r * self.scaleFactor, math.pi/2, 50, 1.0, 1.0, v.color)
    end
end

M.msgHandler = {}


M.msgHandler["Login"] = function (self,event)
	cclog("LoginOK")
    local wpk = net.NewWPacket()
    wpk:WriteTable({cmd="EnterBattle"})
    send2Server(wpk)	
end

M.msgHandler["FixTime"] = function (self,event)
	local nowTick = net.GetSysTick()
	local elapse = nowTick - self.lastTick
	--cclog("FixTime %d %d %d",elapse , nowTick - event.clientTick , event.clientTick)	 
	self.gameTick = event.serverTick - elapse
end

M.msgHandler["ServerTick"] = function (self,event)
	local nowTick = net.GetSysTick()
	local elapse = nowTick - self.lastTick 
	self.gameTick = event.serverTick - elapse
	self.lastFixTime = nowTick
end

M.msgHandler["BeginSee"] = function (self,event)
	--cclog("localServerTick %d,event.timestamp %d",self:GetServerTick(),event.timestamp)
	for k,v in pairs(event.balls) do
		local color = config.colors[v.color]
		color = cc.c4f(color[1],color[2],color[3],color[4])
		local newBall = ball.new(self,v.userID,v.id,v.pos,color,v.r)
		self.balls[newBall.id] = newBall
	end
end

M.msgHandler["BallUpdate"] = function(self,event)
	local ball = self.balls[event.id]
	ball:OnBallUpdate(event)
end

M.msgHandler["EnterRoom"] = function(self,event)
	cclog("star count:%d",#event.stars * 32)
	star.OnStars(event.stars)
end

function scene:processDelayMsg()
	local tick = self:GetServerTick()
	while #self.delayMsgQue > 0 do
		local msg = self.delayMsgQue[1]
		if msg.timestamp >= tick then
			table.remove(self.delayMsgQue,1)
			--cclog("processDelayMsg:%s",msg.cmd)
			local handler = M.msgHandler[msg.cmd]
			if handler then
				handler(self,msg)
			end			
		else
			return
		end
	end
end

function scene:DispatchEvent(event)
	local cmd = event.cmd
	--有timestamp参数的消息需要延时处理
	if event.timestamp then
		--将消息延时M.delayTick处理
		event.timestamp = event.timestamp + M.delayTick
		table.insert(self.delayMsgQue,event)
		return
	end
	--cclog("DispatchEvent:%s",cmd)
	local handler = M.msgHandler[cmd]
	if handler then
		handler(self,event)
	end
end


return M