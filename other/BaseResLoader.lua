local BaseResLoader = class("BaseResLoader")
local FightConst     = require("app.views.fight.FightConst")
local LoadConst   = require("app.views.component.LoadingConst")
local TextureCache = cc.Director:getInstance():getTextureCache()
local spriteFrameCache = cc.SpriteFrameCache:getInstance()

function BaseResLoader:ctor()
    
end

--一般需要重写
function BaseResLoader:initLoadList()
    self.loadList = {}
    self.curStep = 0
    LoadConst.loadedInfo.skeletonRecord = LoadConst.loadedInfo.skeletonRecord or {}
end

function BaseResLoader:loadFont(fontSize , fontTxt , fontName)
    table.insert(self.loadList , { LoadConst.LoadType.obj , function()
        local font = ccui.Text:create()
	    font:setFontSize(fontSize)
	    font:setFontName(fontName or G_DEFAULT_FONT)
        font:setString(fontTxt)
        font:getContentSize()
    end })
end

function BaseResLoader:loadMusic(musicPath)
    if self.musicFlag[musicPath] then return end
    self.musicFlag[musicPath] = true
    table.insert(self.loadList , { LoadConst.LoadType.music , musicPath })
end

-- 每帧加载
function BaseResLoader:loadPerFrame()
    if not self.loadList then return false , 0 , 10000 end
    local i = 1
    while i <= 1 do
        self.curStep = self.curStep + 1
        if self.curStep <= #self.loadList then
            local loadInfo = self.loadList[self.curStep]
            if loadInfo[1] == LoadConst.LoadType.waitTrue then
                if not loadInfo[2]() then
                    self.curStep = self.curStep - 1
                    return false , self.curStep , #self.loadList
                end
            elseif loadInfo[1] == LoadConst.LoadType.animation then
                local spritePath = loadInfo[2]
                if not AnimationCache:isLoadedSkeleton(spritePath .. ".skel") then
                    if cc.FileUtils:getInstance():isFileExist(spritePath..".skel") then
                        AnimationCache:loadSkeleton(spritePath..".skel", spritePath ..".atlas" , 1)
                        table.insert(LoadConst.loadedInfo.skeletonRecord , spritePath .. ".skel")
                        i = i + 1
                    end
                end
            elseif loadInfo[1] == LoadConst.LoadType.img then
                TextureCache:addImage(loadInfo[2])
                i = i + 1
            elseif loadInfo[1] == LoadConst.LoadType.music then
                audio.preloadMusic(loadInfo[2])
                i = i + 1
            elseif loadInfo[1] == LoadConst.LoadType.obj then
                loadInfo[2](self.loadList)
                i = i + 2
            elseif loadInfo[1] == LoadConst.LoadType.plist then
		        spriteFrameCache:addSpriteFrames(loadInfo[2])
                i = i + 1
            end
        else
            local length = #self.loadList
            self.loadList = nil
            self.curStep = 0
            return true, length , length
        end
    end
    return false , self.curStep , #self.loadList
end

function BaseResLoader:clean()
    self.isClean = true
end

-- 检测加载
function BaseResLoader:checkLoad()
    if not self.isClean then
        self:clean()
    elseif not self.loadList then
        self:initLoadList()
    end
    return self:loadPerFrame()
end

--释放所有资源
function BaseResLoader:desposeResource()

end

return BaseResLoader