-- CC_USE_DEPRECATED_API = true
--package.cpath = './src/?.so;'
require "cocos.init"
local net = require("net")
-- cclog
cclog = function(...)
    print(string.format(...))
end

userID = 1001
conn2Server = nil

-- for CCLuaEngine traceback
function __G__TRACKBACK__(msg)
    cclog("----------------------------------------")
    cclog("LUA ERROR: " .. tostring(msg) .. "\n")
    cclog(debug.traceback())
    cclog("----------------------------------------")
end

function send2Server(msg)
    if conn2Server then
        net.Send(conn2Server,msg)
    end
end

local function initGLView()
    local director = cc.Director:getInstance()
    local glView = director:getOpenGLView()
    if nil == glView then
        glView = cc.GLViewImpl:create("Lua Empty Test")
        director:setOpenGLView(glView)
    end

    director:setOpenGLView(glView)

    glView:setDesignResolutionSize(1024, 768, cc.ResolutionPolicy.NO_BORDER)

    --turn on display FPS
    director:setDisplayStats(true)

    --set FPS. the default value is 1.0/60 if you don't call this
    director:setAnimationInterval(1.0 / 60)
end

local function main()
    -- avoid memory leak
    collectgarbage("setpause", 100)
    collectgarbage("setstepmul", 5000)
    initGLView()
    local Scene = require("scene")
    local visibleSize = cc.Director:getInstance():getVisibleSize()
    local origin = cc.Director:getInstance():getVisibleOrigin()
    local scene

    cclog("origin(%d, %d) visibleSize(%d, %d)", origin.x, origin.y, visibleSize.width, visibleSize.height)

    -- create farm
    local function createLayerFarm()
        local layerFarm = cc.Layer:create()
        math.randomseed(os.time())
        local draw = cc.DrawNode:create()
        layerFarm:addChild(draw, 10)
        scene = Scene.New():Init(draw)

        net.Connect("127.0.0.1",8010,function (s,success)
            if success then 
                cclog("connect to server ok")
                conn2Server = s
                net.Bind(s,net.PacketDecoder(),function (s,rpk)
                    if rpk then
                        local msg = rpk:ReadTable()
                        --将网络包交给场景处理
                        scene:DispatchEvent(msg)
                    else
                        --连接断开
                        conn2Server = nil
                    end
                end)

                local wpk = net.NewWPacket()
                wpk:WriteTable({cmd="Login",userID=userID})
                net.Send(s,wpk)
            end
        end)

        function tick()
            net.Run(0)
            scene:Update()
            scene:Render()
        end
        cc.Director:getInstance():getScheduler():scheduleScriptFunc(tick, 1/60, false)   
        return layerFarm
    end

    -- create menu
    local function createLayerMenu()
        local layerMenu = cc.Layer:create()
        local spit,split

        --吐子弹
        local function onSpit()
            cclog("onSpit")
        end
        
        -- add the left-bottom "tools" menu to invoke menuPopup
        local spitItem = cc.MenuItemImage:create("menu1.png", "menu1.png")
        spitItem:setPosition(0, 0)
        spitItem:registerScriptTapHandler(onSpit)
        spit = cc.Menu:create(spitItem)
        local itemWidth = spitItem:getContentSize().width
        local itemHeight = spitItem:getContentSize().height
        spit:setPosition(origin.x + itemWidth/2 + 700, origin.y + itemHeight/2 + 50)
        layerMenu:addChild(spit)

        --分裂
        local function onSplit()
            cclog("onSplit")
        end

        local splitItem = cc.MenuItemImage:create("menu1.png", "menu1.png")
        splitItem:setPosition(0, 0)
        splitItem:registerScriptTapHandler(onSplit)
        split = cc.Menu:create(splitItem)
        local itemWidth = splitItem:getContentSize().width
        local itemHeight = splitItem:getContentSize().height
        split:setPosition(origin.x + itemWidth/2 + 850, origin.y + itemHeight/2 + 50)
        layerMenu:addChild(split)

        return layerMenu
    end
    -- run
   local function createJoyStick()

        local layerJoyStick = cc.Layer:create()

        local nodeJoyStick = cc.Node:create()

        layerJoyStick:addChild(nodeJoyStick)

        local plate = cc.Sprite:create("rocker/plate.png")
        plate:setPosition(origin.x + 150, origin.y + 150)
        nodeJoyStick:addChild(plate)


        local stick = cc.Sprite:create("rocker/stick.png")
        stick:setPosition(origin.x + 150, origin.y + 150)
        nodeJoyStick:addChild(stick)


        local beginPos = cc.p(0, 0)
        local stickDirVec = {x = 0, y = 0}
        local stickDir = 0
        local totalDetal = 0

        local touchMoving


        local function onTouchBegan(touch, event)
            local location = touch:getLocation()
            plate:setPosition(location)
            stick:setPosition(location)
            beginPos = location
            cclog("onTouchBegan: %0.2f, %0.2f", location.x, location.y)
            return true
        end

        local function onTouchMoved(touch, event)
            local location = touch:getLocation()
            local dirVec = cc.pSub(location, beginPos)
            local dir = math.deg(cc.pToAngleSelf(dirVec))
            if dir < 0 then
                dir = dir + 360
            end
                    
            local pos = location
            local norDir = cc.pNormalize(dirVec)
            stickDir = dir
            stickDirVec = norDir
            if cc.pGetDistance(beginPos, location) > 100 then    
                pos = cc.pAdd(beginPos, cc.p(norDir.x * 100, norDir.y * 100))
            end
            stick:setPosition(pos)
            cclog("onTouchMoved: %0.2f, %0.2f dir:%d", location.x, location.y,dir)
            touchMoving = true
                
            local wpk = net.NewWPacket()
            wpk:WriteTable({cmd="Move",dir=dir})
            send2Server(wpk)     
            
        end
        
        local function onTouchEnded(touch, event)
            local pos = cc.p(origin.x + 150, origin.y + 150)
            plate:setPosition(pos)
            stick:setPosition(pos)
            cclog("onTouchEnded: %0.2f, %0.2f", pos.x, pos.y)

            if not touchMoving then
                local wpk = net.NewWPacket()
                wpk:WriteTable({cmd="Stop"})
                send2Server(wpk)
                cclog("stop")
            end
            touchMoving = nil
        end

        local listener = cc.EventListenerTouchOneByOne:create()
        listener:registerScriptHandler(onTouchBegan,cc.Handler.EVENT_TOUCH_BEGAN )
        listener:registerScriptHandler(onTouchMoved,cc.Handler.EVENT_TOUCH_MOVED )
        listener:registerScriptHandler(onTouchEnded,cc.Handler.EVENT_TOUCH_ENDED )    
        local dispatcher = nodeJoyStick:getEventDispatcher()
        dispatcher:addEventListenerWithSceneGraphPriority(listener, nodeJoyStick)
        return layerJoyStick

    end 

    local sceneGame = cc.Scene:create()
    sceneGame:addChild(createLayerFarm())
    sceneGame:addChild(createJoyStick()) 
    sceneGame:addChild(createLayerMenu())   
    cc.Director:getInstance():runWithScene(sceneGame)

end

xpcall(main, __G__TRACKBACK__)
