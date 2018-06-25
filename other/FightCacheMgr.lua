local FightCacheMgr		= class("FightCacheMgr")
local Animation      = require("app.lib.Animation")

function FightCacheMgr:addCache(key , cnt , ctor , reset , dtor)
    self.unusedList = self.unusedList or {}
    self.activeList = self.activeList or {}
    if not self.unusedList[key] then
        self.unusedList[key] = {
            ctor = ctor,
            reset = reset,
            dtor = dtor,
            cache = {}
        }
    end
    for i = 1 , cnt do
        local effect = self.unusedList[key].ctor()
        effect.___key = key
        effect.___visible = effect:isVisible()
        effect.___isCache = true
        effect:setVisible(false)
        effect:retain()
        table.insert(self.unusedList[key].cache , effect)
    end
end

-- 图片
function FightCacheMgr:addImageCache(path_val , cnt)
    self:addCache(path_val , cnt , function()
        local img = ccui.ImageView:create()
        img:loadTexture(path_val, 1)
        return img
    end)
end

-- 子弹
function FightCacheMgr:addBullCache(data , cnt)
    local key = "Bull" .. "__" .. data.classType .. "__" .. ( data.path or data.imgBull or "nil" )
    self:addCache(key, cnt , function()
        local type = data.classType
	    local class = "app.effect.FrameBull"
	    if type == "skeleton" then
            class = "app.effect.SkeletonBull"
        elseif type == "laser" then
		    class = "app.effect.LaserBull"
		elseif type == "dragon" then
		    class = "app.effect.DragonBull"
	    end
        return packMgr:addPackage(class).new(data)
    end)
end

function FightCacheMgr:getBullCache(data)
    local key = "Bull" .. "__" .. data.classType .. "__" .. ( data.path or data.imgBull or "nil" )
    return self:getCache(key)
end

--动画部分
function FightCacheMgr:addAniCache(path_val , cnt)
    self:addCache(path_val , cnt , function()
        return Animation.new({skel = path_val ..".skel", atlas = path_val ..".atlas"})
    end)
end

--粒子部分
function FightCacheMgr:addParticleCache(path_val , cnt , ...)
    self:addCache(path_val , cnt , function()
        local particle = cc.ParticleSystemQuad:create(path_val)
	    particle:setAutoRemoveOnFinish(true)
        return particle
    end,function(item)
        item:resetSystem()
    end)
end

--类型部分
function FightCacheMgr:addClassCache(key , path_val , cnt , ...)
    local args = { ... }
    self:addCache(key or path_val, cnt , function()
        return packMgr:addPackage(path_val).new(unpack(args))
    end)
end

function FightCacheMgr:getCache(key)
    if not self.unusedList[key] then
        print("cache is not Exist:" .. key)
        return
    end
    self.activeList[key] = self.activeList[key] or {}
    local item
    if #self.unusedList[key].cache == 0 then
        print("cache is empty:" .. key)
        item = self.unusedList[key].ctor()
        item.___key = key
        item.___isCache = true
        item:retain()
    else
        item = table.remove(self.unusedList[key].cache , 1)
        if item.___visible then
            item:setVisible(true)
        end
        item.___visible = nil
    end
    item.___isCache = nil
    self.activeList[key][item] = item
    return item
end

function FightCacheMgr:enterCache(item)
    if not self.unusedList or not self.activeList then
        print("can not cache it." .. (key or "nil"))
        return 
    end
    local key = item.___key
    if not key or not self.unusedList[key] then
        if key then
            print("can not cache it." .. (key or "nil"))
        end
        return
    end
    if self.activeList[key][item] then
        if self.unusedList[key].reset then
            self.unusedList[key].reset(item)
        end
        item.___visible = item:isVisible()
        item:setVisible(false)
        item.___isCache = true
        table.insert(self.unusedList[key].cache , item)
        self.activeList[key][item] = nil
    end
end

function FightCacheMgr:isInCached(item)
    return item.___isCache
end

function FightCacheMgr:clearAll()
    if not self.unusedList and not activeList then
        return
    end
    for _ , cacheInfo in pairs(self.unusedList) do
        for _ , v in ipairs(cacheInfo.cache) do
            if cacheInfo.dtor then
                cacheInfo.dtor(v)
            end
            v:release()
        end
        cacheInfo.cache= {}
    end
    for _ , cacheList in pairs(self.activeList) do
        for _ , v in pairs(cacheList) do
            local key = v.___key
            if self.unusedList[key].dtor then
                self.unusedList[key].dtor(v)
            end
            v.___isCache = nil
            v:release()
        end
    end
    self.unusedList = nil
    self.activeList = nil
end

return FightCacheMgr