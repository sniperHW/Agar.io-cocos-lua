local net = require("net")
local ball = require("ball")
local config = require("config")
local star = require("star")
local util = require("util")
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
		leftBottom.x = M.viewBounderyTopRight.x - self.viewPort.width
	end

	if leftBottom.y + self.viewPort.height > M.viewBounderyTopRight.y then
		leftBottom.y = M.viewBounderyTopRight.y - self.viewPort.height
	end	

	self.viewPort.leftBottom = leftBottom

end

function scene:setViewPort(width,height)
    self.viewPort = self.viewPort or {}	
    self.viewPort.width = width
    self.viewPort.height = height
    self.scaleFactor = M.visibleSize.width/self.viewPort.width
    --cclog("scaleFactor:%f",self.scaleFactor)
end

function scene:Init(drawer)
	cclog("(%d, %d, %d, %d)", M.origin.x, M.origin.y, M.visibleSize.width, M.visibleSize.height)
	self.serverTickDelta = 0
	self.gameTick = 0
	self.lastTick = net.GetSysTick()
	self.drawer = drawer
    self.balls = {}
    self.delayMsgQue = {}
    self.centralPos = {x = M.width/2, y = M.height/2 }
    self.oldCentralPos = {x = M.width/2, y = M.height/2 }
    self:setViewPort(M.visibleSize.width,M.visibleSize.height)    
    self:updateViewPortLeftBottom()
	return self
end

function scene:UpdateTick()
	local nowTick = net.GetSysTick()
	--[[if self.lastFixTime then
		if nowTick - self.lastFixTime > 1000 then
			local wpk = net.NewWPacket()
    		wpk:WriteTable({cmd="FixTime",clientTick=nowTick})
    		send2Server(wpk)
			self.lastFixTime = nowTick
		end
	end]]
	self.elapse = nowTick - self.lastTick	
	self.gameTick = self.gameTick + self.elapse
	self.lastTick = nowTick
end

function scene:UpdateViewPort(selfBalls)
	if #selfBalls == 0 then
		return
	end

	if #selfBalls == 1 then
		local baseR = config.Score2R(config.initScore)
		local R = config.Score2R(selfBalls[1].r)
		if R == baseR then
			self:setViewPort(M.visibleSize.width,M.visibleSize.height)
		else
			local viewPortWidth =  math.floor((1+(R/baseR)/10) * M.visibleSize.width)
			viewPortWidth = math.min(viewPortWidth,config.mapWidth)
			local viewPortHeight = math.floor((M.visibleSize.height * viewPortWidth)/M.visibleSize.width)
			self:setViewPort(viewPortWidth,viewPortHeight)
		end
	else
		local maxDeltaX = 0
		local maxDeltaY = 0
		for k,v in pairs(selfBalls) do
			local vv = util.vector2D.new(v.pos.x - self.centralPos.x , v.pos.y - self.centralPos.y)
			local p = util.point2D.moveto(v.pos,vv:getDirAngle(),v.r)
			local deltaX = math.abs(p.x - self.centralPos.x)
			local deltaY = math.abs(p.y - self.centralPos.y)
			maxDeltaX = math.max(deltaX , maxDeltaX)
			maxDeltaY = math.max(deltaY , maxDeltaY)
		end

		--cclog("maxDeltaX %d,maxDeltaY %d",maxDeltaX,maxDeltaY)

		if maxDeltaX/M.visibleSize.width > maxDeltaY/M.visibleSize.height then
			if maxDeltaX > M.visibleSize.width/5 then
				local viewPortWidth = self.viewPort.width/2 + maxDeltaX + 300
				viewPortWidth = math.min(viewPortWidth,config.mapWidth)
				local viewPortHeight = math.floor((M.visibleSize.height * viewPortWidth)/M.visibleSize.width)
				self:setViewPort(viewPortWidth,viewPortHeight)			
			else
				self:setViewPort(M.visibleSize.width,M.visibleSize.height)
			end
		else
			if maxDeltaY > M.visibleSize.height/5 then
				local viewPortHeight = self.viewPort.height/2 + maxDeltaY + 300
				viewPortHeight = math.min(viewPortHeight,config.mapWidth)
				local viewPortWidth = math.floor((M.visibleSize.width * viewPortHeight)/M.visibleSize.height)
				self:setViewPort(viewPortWidth,viewPortHeight)			
			else
				self:setViewPort(M.visibleSize.width,M.visibleSize.height)
			end
		end

	end
	
end

function scene:Update()
	local elapse = self.elapse
	self:processDelayMsg()
	local ownBallCount = 0
	local cx = 0
	local cy = 0
	local selfBalls = {}
	for k,v in pairs(self.balls) do
		v:Update(elapse)
		if v.userID == userID then
			cx = cx + v.pos.x
			cy = cy + v.pos.y
			ownBallCount = ownBallCount + 1
			table.insert(selfBalls,v)
		end
	end
	if ownBallCount > 0 then
		self.centralPos.x = cx/ownBallCount
		self.centralPos.y = cy/ownBallCount
		self:UpdateViewPort(selfBalls)
		self:updateViewPortLeftBottom()
	end

	local secRemain = max(0,math.floor(config.gameTime - self.gameTick/1000))
	local min = secRemain/60
	local sec = secRemain%60
	local timeStr = string.format("%d:%.2d",min,sec)
	UpdateTime(timeStr)

end

function scene:Render()
    self.drawer:clear()
    star.Render(self)

    local balls = {}
    for k,v in pairs(self.balls) do
    	table.insert(balls,v)
    end

    --按score从小到大排序
    table.sort(balls,function (a,b)
    	return a.r < b.r
    end)

    for k,v in pairs(balls) do
    	local viewPortPos = self:world2ViewPort(v.pos)

    	local topLeft = {x = viewPortPos.x - v.r , y = viewPortPos.y + v.r}
    	local bottomLeft = {x = viewPortPos.x - v.r , y = viewPortPos.y - v.r}
    	local topRight = {x = viewPortPos.x + v.r , y = viewPortPos.y + v.r}
    	local bottomRight = {x = viewPortPos.x + v.r , y = viewPortPos.y - v.r}

    	if self:isInViewPort(topLeft) or self:isInViewPort(bottomLeft) or self:isInViewPort(topRight) or self:isInViewPort(bottomRight) then
    		local screenPos = self:viewPort2Screen(viewPortPos)
    		self.drawer:drawSolidCircle(cc.p(screenPos.x ,screenPos.y), v.r * self.scaleFactor, math.pi/2, 50, 1.0, 1.0, v.color)
    	end	
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
	self.gameTick = event.serverTick - elapse
	self.lastFixTime = nowTick
end

M.msgHandler["ServerTick"] = function (self,event)
	local nowTick = net.GetSysTick()
	local elapse = nowTick - self.lastTick 
	self.gameTick = event.serverTick - elapse
	self.lastFixTime = nowTick	
end

M.msgHandler["BeginSee"] = function (self,event)
	for k,v in pairs(event.balls) do
		local color
		if v.color == config.thornColorID then
			color = config.thornColor
		else 
			color = config.colors[v.color]
		end
		color = cc.c4f(color[1],color[2],color[3],color[4])
		local newBall = ball.new(self,v.userID,v.id,v.pos,color,v.r,v.velocitys)
		self.balls[newBall.id] = newBall
	end
end

M.msgHandler["EndSee"] = function (self,event)
	for k,v in pairs(event.balls) do
		self.balls[v] = nil
	end	
end

M.msgHandler["BallUpdate"] = function(self,event)
	local timestamp = event.timestamp
	for k,v in pairs(event.balls) do
		local ball = self.balls[v.id]
		if ball then
			ball:OnBallUpdate(event,v,timestamp)
		else
			cclog("ball unfind:%d",v.id)
		end
	end
end

M.msgHandler["EnterRoom"] = function(self,event)
	cclog("star count:%d",#event.stars * 32)
	star.OnStars(event)
end

M.msgHandler["StarDead"] = function(self,event)
	star.OnStarDead(event)
end

M.msgHandler["StarRelive"] = function(self,event)
	star.OnStarRelive(event)
end

M.msgHandler["GameOver"] = function(self,event)
	self.gameOver = true
	showGameOver()
end

function scene:processDelayMsg()
	local tick = self:GetServerTick()
	while #self.delayMsgQue > 0 do
		local msg = self.delayMsgQue[1]
		if msg.timestamp <= tick then
			table.remove(self.delayMsgQue,1)
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
		local nowTick = net.GetSysTick()
		local elapse = nowTick - self.lastTick		 
		event.timestamp = event.timestamp + M.delayTick - elapse
		table.insert(self.delayMsgQue,event)
		return
	end
	local handler = M.msgHandler[cmd]
	if handler then
		handler(self,event)
	end
end


return M