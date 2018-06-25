
local Editor = class("Editor")
editorTools = require("app.EditorTools")

function Editor:ctor()
    self.menuDraw = { length = 0 }
    self.editorDraw = { length = 0 }
    self:init()
end

function Editor:init()
    self._viewEnterHandler = modelMgr.guide:addEventListener(GuideConst.GUIDE_EVENT.UI_VIEW_ENTER , function(event)
        local view = event.args
        if view.onEditorMenu then
            self:addDraw(self.menuDraw , view , function()
                if tolua.isnull(view) then
                    self:removeDraw(self.menuDraw , view)
                    return false
                end
                view:onEditorMenu()
                return true
            end)
        end
        if view.onEditorViewWrap then
            self:addDraw(self.editorDraw , view , function()
                if tolua.isnull(view) then
                    self:removeDraw(self.editorDraw , view)
                    return false 
                end
                view:onEditorViewWrap()
                return true
            end)
        end
    end) 
    self._viewExitHandler = modelMgr.guide:addEventListener(GuideConst.GUIDE_EVENT.UI_VIEW_EXIT , function(event)
        local view = event.args
        self:removeDraw(self.menuDraw , view)
        self:removeDraw(self.editorDraw , view)
    end) 
end

function Editor:dtor()
    if self._viewEnterHandler then
        modelMgr.guide:removeEventHandler(self._viewEnterHandler)
    end
    if self._viewExitHandler then
        modelMgr.guide:removeEventHandler(self._viewExitHandler)
    end
end

function Editor:addDrawFunc(func)
    self:addDraw(self.editorDraw , "DrawFunc" , func)
end

function Editor:addDraw(map , key , func)
    if not map[key] then
        map[key] = {}
        map.length = map.length + 1
    end
    table.insert(map[key] , func)
end

function Editor:removeDraw(map , key)
    if map[key] then
        map[key] = nil
        map.length = map.length - 1
    end
end

function Editor:draw()
    if not CLOSE_EDITOR_MENU then
        if self.menuDraw.length > 0 then
            if imgui.beginMainMenuBar() then
                self:drawList(self.menuDraw)
                imgui.endMainMenuBar()
            end
        end
    end
    self:drawList(self.editorDraw)
end

function Editor:drawList(drawMap)
    for _ , list in pairs(drawMap) do
        if type(list) == "table" then
            for _ , v in pairs(list) do
                v()
            end
        end
    end
end

return Editor