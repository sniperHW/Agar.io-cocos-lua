local util = require("util")
local config = require("config")
local M = {}

local ball = {}
ball.__index = ball

function M.new(scene,userID,ballID,pos,color,r,velocitys)
	local o = {}
	o = setmetatable(o,ball)
	o.userID = userID
	o.id = ballID
	o.pos = {x = pos.x,y = pos.y}
	o.color = color
	o.r = r
	o.scene = scene
	if velocitys and #velocitys > 0 then
		o.velocitys = {}
		for k,v in pairs(velocitys) do
			local v0 = util.vector2D.new(v.v.x , v.v.y)
			local v1 = util.vector2D.new(v.targetV.x , v.targetV.y)
			table.insert(o.velocitys,util.velocity.new(v0 , v1 , v.accRemain , v.duration))
		end
	end
	return o
end

function ball:UpdatePosition(averageV,elapse)
	self.pos.x = self.pos.x + averageV.x * elapse
	self.pos.y = self.pos.y + averageV.y * elapse
	local bottomLeft = {x = 0, y = 0}
	local topRight = {x = config.mapWidth, y = config.mapWidth}
	local R = self.r * math.sin(util.PI/4)
	self.pos.x = util.max(R + bottomLeft.x,self.pos.x)
	self.pos.x = util.min(topRight.x - R,self.pos.x)
	self.pos.y = util.max(R + bottomLeft.y,self.pos.y)
	self.pos.y = util.min(topRight.y - R,self.pos.y)
end

function ball:Update(elapse)
	if self.v then
		if self.v.duration <= 0 then
			if nil == self.predictV then
				return
			end

			if util.vector2D.new(self.predictV.x , self.predictV.y):mag() <= 0 then
				self.predictV = nil
				return
			end 

			--运动量已经用完，使用预测速度移动
			self.v = util.velocity.new(util.vector2D.new(self.predictV.x , self.predictV.y))
			self.usePredict = true
		end
		local v = self.v:Update(elapse)
		self:UpdatePosition(v,elapse/1000)
	elseif self.velocitys then
		local v = util.vector2D.new(0,0)
		for kk,vv in pairs(self.velocitys) do
			v = v + vv:Update(elapse)
			if vv.duration <= 0 then
				self.velocitys[kk] = nil
			end
		end
		self:UpdatePosition(v,elapse/1000)
	end
end

function ball:OnBallUpdate(msg)
	self.velocitys = nil
	self.r = msg.r

	if not msg.elapse then
		return
	end

	local delay = self.scene:GetServerTick() - msg.timestamp
	local elapse = msg.elapse - delay
	if elapse <= 0 then
		print("set pos",self.scene:GetServerTick())
		--延迟太严重无法平滑处理，直接拖拽
		self.predictV = msg.v
		self.pos.x = msg.pos.x
		self.pos.y = msg.pos.y
		self.v = util.velocity.new(util.vector2D.new(self.predictV.x , self.predictV.y))
		return
	end	

	self.usePredict = false
	self.predictV = msg.v
	--计算速度
	local v = util.vector2D.new(msg.pos.x - self.pos.x, msg.pos.y - self.pos.y)/(elapse/1000)
	self.v = util.velocity.new(v,nil,nil,elapse)
end

return M
