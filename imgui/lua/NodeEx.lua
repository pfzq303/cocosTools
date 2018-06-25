--[[

Copyright (c) 2011-2014 chukong-inc.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

]]

local Node = cc.Node
Node.G_OPEN_NODE_EVENT = true --开启node事件
function Node:add(child, zorder, tag)
    if tag then
        self:addChild(child, zorder, tag)
    elseif zorder then
        self:addChild(child, zorder)
    else
        self:addChild(child)
    end
    return self
end

function Node:checkVisible()
    local visible = self:isVisible()
    local parent = self:getParent()
    while( visible and parent) do
        visible = parent:isVisible()
        parent = parent:getParent()
    end
    return visible
end

function Node:addTo(parent, zorder, tag)
    if tag then
        parent:addChild(self, zorder, tag)
    elseif zorder then
        parent:addChild(self, zorder)
    else
        parent:addChild(self)
    end
    return self
end

function Node:removeSelf()
    self:removeFromParent()
    return self
end

function Node:align(anchorPoint, x, y)
    self:setAnchorPoint(anchorPoint)
    return self:move(x, y)
end

function Node:show()
    self:setVisible(true)
    return self
end

function Node:hide()
    self:setVisible(false)
    return self
end

function Node:move(x, y)
    if y then
        self:setPosition(x, y)
    else
        self:setPosition(x)
    end
    return self
end

function Node:moveTo(args)
    transition.moveTo(self, args)
    return self
end

function Node:moveBy(args)
    transition.moveBy(self, args)
    return self
end

function Node:fadeIn(args)
    transition.fadeIn(self, args)
    return self
end


--[[
设置位置到指定Node中心点 
默认是父节点的中心
--]]
function Node:setCenterPoint(node)
	local parentNode = node or self:getParent()
	local anchorPoin = self:getAnchorPoint()
	local nodeSize = parentNode:getContentSize()
	local size  = self:getContentSize()
	local x = (anchorPoin.x - 0.5) * size.width
	local y = (anchorPoin.y - 0.5) * size.height
	self:setPosition(x + nodeSize.width/2, y + nodeSize.height/2)
end

function Node:fadeOut(args)
    transition.fadeOut(self, args)
    return self
end

function Node:fadeTo(args)
    transition.fadeTo(self, args)
    return self
end

function Node:rotate(rotation)
    self:setRotation(rotation)
    return self
end

function Node:rotateTo(args)
    transition.rotateTo(self, args)
    return self
end

function Node:rotateBy(args)
    transition.rotateBy(self, args)
    return self
end

function Node:scaleTo(args)
    transition.scaleTo(self, args)
    return self
end

function Node:onUpdate(callback)
    self:scheduleUpdateWithPriorityLua(callback, 0)
    return self
end

Node.scheduleUpdate = Node.onUpdate

function Node:onNodeEvent(eventName, callback)
    if "enter" == eventName then
        self.onEnterCallback_ = callback
    elseif "exit" == eventName then
        self.onExitCallback_ = callback
    elseif "enterTransitionFinish" == eventName then
        self.onEnterTransitionFinishCallback_ = callback
    elseif "exitTransitionStart" == eventName then
        self.onExitTransitionStartCallback_ = callback
    elseif "cleanup" == eventName then
        self.onCleanupCallback_ = callback
    end
    self:enableNodeEvents()
end

function Node:enableNodeEvents()
    if self.isNodeEventEnabled_ then
        return self
    end
    self:registerScriptHandler(function(state)
		if not Node.G_OPEN_NODE_EVENT then
			return
		end
        if state == "enter" then
            self:onEnter_()
        elseif state == "exit" then
            self:onExit_()
        elseif state == "enterTransitionFinish" then
            self:onEnterTransitionFinish_()
        elseif state == "exitTransitionStart" then
            self:onExitTransitionStart_()
        elseif state == "cleanup" then
            self:onCleanup_()
        end
    end)
    self.isNodeEventEnabled_ = true

    return self
end

function Node:disableNodeEvents()
    self:unregisterScriptHandler()
    self.isNodeEventEnabled_ = false
    return self
end


function Node:onEnter()
end

function Node:onExit()
end

function Node:onEnterTransitionFinish()

end

function Node:onExitTransitionStart()
end

function Node:onCleanup()
end

function Node:addCleanCallBack(func)
    self._cleanCallbackList = self._cleanCallbackList or {}
    self._cleanIndex = self._cleanIndex and self._cleanIndex + 1 or 1
    self._cleanCallbackList[self._cleanIndex] = func
    return self._cleanIndex
end

function Node:removeCleanCallBack(cleanIndex)
    self._cleanCallbackList[cleanIndex] = nil
end

function Node:onEnter_()
    self:onEnter()
    if not self.onEnterCallback_ then
        return
    end
    self:onEnterCallback_()
end

function Node:onExit_()
    self:onExit()
    if not self.onExitCallback_ then
        return
    end
    self:onExitCallback_()
end

function Node:onEnterTransitionFinish_()
    self:onEnterTransitionFinish()
    if not self.onEnterTransitionFinishCallback_ then
        return
    end
    self:onEnterTransitionFinishCallback_()
end

function Node:onExitTransitionStart_()
    self:onExitTransitionStart()
    if not self.onExitTransitionStartCallback_ then
        return
    end
    self:onExitTransitionStartCallback_()
end

function Node:onCleanup_()
    self:onCleanup()
    if self._cleanCallbackList then
        for _ , v in pairs(self._cleanCallbackList) do
            v()
        end
    end
    if not self.onCleanupCallback_ then
        return
    end
    self:onCleanupCallback_()
end

function Node:clone()
    local node = cc.Node:create()
    node:setScale(self:getScale())
    node:setPosition(self:getPosition())
    node:setRotation(self:getRotation())
    local children = self:getChildren()
    for _, child in pairs(children) do
        local cp = child:clone()
        if cp then
            node:addChild(cp)
        end
    end
    return node
end

if imgui then
function Node:onEditor()
    imgui.pushItemWidth(100)
    imgui.text("Position:") imgui.sameLine()
    editorTools.createNodeEditor(editorTools.Widget_Type.dragFloat  ,self ,"x" , "getPositionX" , "setPositionX")
    imgui.sameLine()
    editorTools.createNodeEditor(editorTools.Widget_Type.dragFloat  ,self ,"y" , "getPositionY" , "setPositionY")
    imgui.popItemWidth()

    imgui.pushItemWidth(100)
    imgui.text("Scale:") imgui.sameLine()
    editorTools.createNodeEditor(editorTools.Widget_Type.dragFloat  ,self ,"scaleX"   , "getScaleX" , "setScaleX" , 0.1)
    imgui.sameLine()
    editorTools.createNodeEditor(editorTools.Widget_Type.dragFloat  ,self ,"scaleY"   , "getScaleY" , "setScaleY" , 0.1)
    imgui.popItemWidth()

    imgui.text("Color:") imgui.sameLine()
    local ret
    local color = self:getColor()
    color.a = self:getOpacity()
    ret , color.r , color.g , color.b , color.a = imgui.colorEdit("color" , color.r / 255 , color.g / 255 , color.b / 255 , color.a / 255)
    if ret then
        color.r = color.r * 255
        color.g = color.g * 255
        color.b = color.b * 255
        color.a = color.a * 255
        self:setColor(color)
        self:setOpacity(color.a)
    end

    imgui.pushItemWidth(100)
    imgui.text("AnchorPoint:") imgui.sameLine()
    local anchorPoint = self:getAnchorPoint()
    editorTools.createNodeEditor(editorTools.Widget_Type.dragFloat  ,anchorPoint ,"ax" , "x" , "x" , 0.01 , 0 , 1)
    imgui.sameLine()
    editorTools.createNodeEditor(editorTools.Widget_Type.dragFloat  ,anchorPoint ,"ay" , "y" , "y" , 0.01 , 0 , 1)
    self:setAnchorPoint(anchorPoint)
    imgui.popItemWidth()

    if self:getRotationSkewX() ~= self:getRotationSkewY() then
        imgui.pushItemWidth(100)
        imgui.text("Rotation:") imgui.sameLine()
        editorTools.createNodeEditor(editorTools.Widget_Type.dragFloat  ,self ,"rotationX", "getRotationSkewX" , "setRotationSkewX", 1, -360 , 360)
        imgui.sameLine()
        editorTools.createNodeEditor(editorTools.Widget_Type.dragFloat  ,self ,"rotationY", "getRotationSkewY" , "setRotationSkewY", 1, -360 , 360)
        imgui.popItemWidth()
    else
        imgui.text("Rotation:") imgui.sameLine()
        editorTools.createNodeEditor(editorTools.Widget_Type.dragFloat  ,self ,"rotation", "getRotation" , "setRotation", 1, -360 , 360)
    end
    
    imgui.text("visible:") imgui.sameLine()
    editorTools.createNodeEditor(editorTools.Widget_Type.checkbox   ,self ,"" , "isVisible" , "setVisible")
end
end