--Ìí¼Ó±à¼­¹¦ÄÜ
if imgui then
    local function generateAniFile()
        local aniNameList = {
        "attack", 
        "attack1", 
        "attack2", 
        "die", 
        "run",
        "idle", 
        "skill1",
        "skill2",
        "tumbel",
        "die_up",
        "transition_ban",
        "skillstart",
        "skillrun",
        "skillend",
        "spell1",
        "spell2",
        "die_1",
        "die_2",
        "die_3",
        "attack_1",
        "attack_2",
        "effect",
        "effect1",
        "effect2",
        "skill_loop",
        "skill1_loop",
        "skill2_loop",
        "skill2_end",
        "skill1_end",
        }
        local Animation  = require("app.lib.Animation")
        local record = {}

        local aniList = {
            {"TOWER|" .. "tower" ,  pathMgr:AnimationBuild("tower")},
            {"TOWER|" .. "tower2" , pathMgr:AnimationBuild("tower2")},
            {"TOWER|" .. "build2" , pathMgr:AnimationBuild("build2")},
           {"TOWER|" .. "build1" , pathMgr:AnimationBuild("build1")},
            {"TOWER|" .. "tower3" , pathMgr:AnimationBuild("tower3")},
            {"TOWER|" .. "jianshe_build" , pathMgr:AnimationBuild("jianshe_build")},
		     {"TOWER|" .. "jianshe_tower" , pathMgr:AnimationBuild("jianshe_tower")},
		    {"TOWER|" .. "jiguang_build" , pathMgr:AnimationBuild("jiguang_build")},
		    {"TOWER|" .. "jiguang_tower" , pathMgr:AnimationBuild("jiguang_tower")},
		    {"TOWER|" .. "putong_build1" , pathMgr:AnimationBuild("putong_build1")},
		    {"TOWER|" .. "putong_build2" , pathMgr:AnimationBuild("putong_build2")},
		    {"TOWER|" .. "putong_tower" , pathMgr:AnimationBuild("putong_tower")},
		    {"TOWER|" .. "sushe_build" , pathMgr:AnimationBuild("sushe_build")},
		    {"TOWER|" .. "sushe_tower" , pathMgr:AnimationBuild("sushe_tower")},
        }

        local EffectConfig = _C("effect_config")
        for _ , v in pairs(EffectConfig) do
            if v.animId ~= "" and not record["EFFECT|" .. v.animId] then 
                record["EFFECT|" .. v.animId] = 1
                table.insert(aniList , {"EFFECT|" .. v.animId , pathMgr:getEffect(v.animId)})
            end
        end
        local IgnoreNames = {
            gaoda = true,
            gaodafly = true
        }
        local SpriteConfig	= _C("npc_config")
        for _ , v in pairs(SpriteConfig) do
            if v.Animation ~= "" and not record["HERO|" .. v.Animation] and not IgnoreNames[v.Animation] then 
                record["HERO|" .. v.Animation] = 1
                table.insert(aniList , {"HERO|" .. v.Animation , pathMgr:Animation(v.Animation)})
            end
        end

        local coro 
        local totalStr = ""

        coro = coroutine.create(function()
            local file = io.open("animation.txt", "w+")  
            for _ , v in ipairs(aniList) do
                local resultStr
                local frameStr
                local sprite1 = Animation.new({skel = v[2] ..".skel", atlas = v[2] ..".atlas", scale = 1})
                sprite1:setPosition(display.center)
                viewMgr._guideLayer:addChild(sprite1)
                local start_time
                sprite1:addEventListener(Animation.SP_ANIMATION_COMPLETE, function()
                    if frameStr ~= "" then
                        resultStr = resultStr .. ("|{" .. string.sub(frameStr , 1 , string.len(frameStr) - 1)  .. "}")
                    end
                    totalStr = totalStr .. resultStr .. "\n"
                    file:write(resultStr .. "\n")
                    coroutine.resume(coro)
                end)

                sprite1:addEventListener(Animation.SP_ANIMATION_EVENT, function(event)
                    local nowTime = os.clock()
                    frameStr = frameStr .. "{frameName=\"" .. event.eventData.name .. "\",frameTime=" .. string.format("%.2f", (nowTime - start_time)) .. "},"
                end)

                for _ , aniNam in ipairs(aniNameList) do
                    if sprite1:hasAnimation(aniNam) then
                        start_time = os.clock()
                        frameStr = ""
                        resultStr = v[1] .. "|" .. aniNam .. "|" .. string.format("%.2f", sprite1:getAnimationTime(aniNam))
                        sprite1:setAnimation(0 , aniNam , false)
                        coroutine.yield()
                    end
                end

                sprite1:runAction(cc.RemoveSelf:create())
            end
            io.close(file)
        end)
        coroutine.resume(coro)
    end
    local isShowDemo = false
    local isShowFrameGraph = false
    local frameArr = {0}
    local memoryArr = {0}
    local gameSpeed = 1
    function addGlobalEditor()
		local str = cc.Director:getInstance():getTextureCache():getCachedTextureInfo()
        editorTools.createUI("text", "skeletonCache:" .. tostring(sp.SkeletonDataCache:getCreateCnt()))
        editorTools.createUI("text", "AltlasCache:" .. tostring(sp.AltlasCache:getCreateCnt()))
		local _, index = string.find(str, "TextureCache dumpDebugInfo:")
		editorTools.createUI("text", "c++:"..string.sub(str, index + 2))
		editorTools.createUI("text",  string.format("Lua Memory: %.2f M", collectgarbage("count")/1024))
        editorTools.createTreeNode("Setting" , function()
            local ret  , v = imgui.checkbox("Demo" , isShowDemo and 1 or 0)
            isShowDemo = v
            if isShowDemo then
                editorTools.showDemo()
            end
    
            local ret  , v = imgui.checkbox("FrameGraph" , isShowFrameGraph and 1 or 0)
            isShowFrameGraph = v
            if isShowFrameGraph then
        
            end

            local ret , v = imgui.checkbox("Game Guide" , OPEN_GUIDE and 1 or 0)
            OPEN_GUIDE = v 
    
            local ret , v = imgui.checkbox("Guide Save" , OPEN_GUIDE_SAVE and 1 or 0)
            OPEN_GUIDE_SAVE = v 

            local ret , v = imgui.checkbox("Show FPS" , CC_SHOW_FPS and 1 or 0)
            if CC_SHOW_FPS ~= v then
                CC_SHOW_FPS = v 
                cc.Director:getInstance():setDisplayStats(CC_SHOW_FPS)
            end

            local ret , v = imgui.checkbox("OpenDebugSync" , G_OpenDebugSync and 1 or 0)
            G_OpenDebugSync = v 

            local ret , v = imgui.checkbox("Game Story" , G_OPEN_STORY and 1 or 0)
            G_OPEN_STORY = v 
    
            local ret , v = imgui.checkbox("Open Editor" , IS_OPEN_EDITOR and 1 or 0)
            IS_OPEN_EDITOR = v 
    
            local ret , v = imgui.checkbox("Open Editor Menu" , CLOSE_EDITOR_MENU and 1 or 0)
            CLOSE_EDITOR_MENU = v 
           
            local ret , v = imgui.sliderFloat("gameSpeed:" , gameSpeed , 0 , 3)
            if gameSpeed ~= v then
                gameSpeed = v
                cc.Director:getInstance():getScheduler():setTimeScale(gameSpeed)
            end
            editorTools.createTreeNode("memory" , function()
                table.insert(memoryArr , collectgarbage("count"))
                if #memoryArr >= 200 then
                    table.remove(memoryArr , 1)
                end 
                imgui.plotLines("" , memoryArr , 0 , "memory" , 0 , 30000 , 0 , 100)
            end)
            table.insert(frameArr , cc.Director:getInstance():getFrameRate())
            if #frameArr >= 200 then
                table.remove(frameArr , 1)
            end
            imgui.plotLines("" , frameArr , 0 , "frameNum" , 0 , 60 , 0 , 100)

        end)
        viewMgr:onEditor()
        editorTools.createTreeNode("Guide" , function()
            guideMgr:onEditor()
        end)
        editorTools.createTreeNode("Tools" , function()
            if imgui.button("generateAniFile") then
                generateAniFile()
            end
        end)
    end
    print (imgui.version)
    local editor = require("app.Editor").new()
    editor:addDrawFunc(addGlobalEditor)
    imgui.draw = function ()
        if IS_OPEN_EDITOR then
            editor:draw()
        end
    end

end