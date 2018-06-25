local editorTools = {}  
--    // Main
--    M(showStyleEditor),

--    // Window
--    {"endToLua", imgui_end},
--    M(begin), M(beginChild), M(endChild),
--	M(showDemo),
--    M(setNextWindowPos),
--    M(setNextWindowPosCenter),
--    M(setNextWindowSize),
--    M(setNextWindowContentSize),
--    M(setWindowPos),
--    M(setWindowSize),

--    // Cursor / Layout
--    M(beginGroup),
--    M(endGroup),
--    M(separator),
--    M(sameLine),
--    M(spacing),
--    M(dummy),
--    M(indent),
--    M(unindent),
--    M(getCursorPos),
--    M(getCursorScreenPos),

--	// Tree
--	M(treeNode),
--	M(treePop),
--	M(nextColumn),
--	M(alignFirstTextHeightToWidgets),
--	M(selectable),

--    // Widgets
--    M(text),
--    M(textColored),
--    M(textDisabled),
--    M(textWrapped),
--    M(labelText),
--    M(bullet),
--    M(bulletText),
--    M(button),
--    M(smallButton),
--    M(image),
--    M(imageButton),
--    M(collapsingHeader),
--    M(checkbox),
--    M(checkboxFlags),
--    M(radioButton),
--    M(combo),
--	M(colorButton),

--	//
--	M(pushStyleVar),
--	M(popStyleVar),
--	M(columns),

--	M(beginPopupContextItem),
--	M(endPopup),

--    // Widgets: Drags
--    M(dragFloat),
--    M(dragFloat2),
--    M(dragInt),
--    M(dragInt2),

--    // Widgets: Input with Keyboard
--    M(inputText),
--    M(inputMultiline),
--    M(inputFloat),
--    M(inputFloat2),
--    M(inputInt),
--    M(inputInt2),

--    // Widgets: Sliders

--    M(sliderFloat),
--    M(sliderFloat2),
--    M(sliderAngle),
--    M(sliderInt),
--    M(sliderInt2),
--    M(vSliderFloat),
--    M(vSliderInt),

--    // Menus
--    M(beginMainMenuBar),
--    M(endMainMenuBar),
--    M(beginMenuBar),
--    M(endMenuBar),
--    M(beginMenu),
--    M(endMenu),
--    M(menuItem),

--	M(pushItemWidth),
--	M(popItemWidth),

--    M(pushId),
--    M(popId),
--    {NULL,  NULL}

editorTools.Widget_Type = {
--    // Widgets
      text = "text",
      textColored = "textColored",
      textDisabled = "textDisabled",
      textWrapped = "textWrapped",
      labelText = "labelText",
      bullet = "bullet",
      bulletText = "bulletText",
      button = "button",
      smallButton = "smallButton",
      image = "image",
      imageButton = "imageButton",
      collapsingHeader = "collapsingHeader",
      checkbox = "checkbox",
      checkboxFlags = "checkboxFlags",
      radioButton = "radioButton",
      combo = "combo",
      colorButton = "colorButton",

--    // Widgets: Drags
      dragFloat = "dragFloat",
      dragFloat2 = "dragFloat2",
      dragInt = "dragInt",
      dragInt2 = "dragInt2",

--    // Widgets: Input with Keyboard
      inputText = "inputText",
      inputMultiline = "inputMultiline",
      inputFloat = "inputFloat",
      inputFloat2 = "inputFloat2",
      inputInt = "inputInt",
      inputInt2 = "inputInt2",

--    // Widgets: Sliders
      sliderFloat = "sliderFloat",
      sliderFloat2 = "sliderFloat2",
      sliderAngle = "sliderAngle",
      sliderInt = "sliderInt",
      sliderInt2 = "sliderInt2",
      vSliderFloat = "vSliderFloat",
      vSliderInt = "vSliderInt",
}

editorTools.showDemo = function()
    imgui.showDemo()
end

editorTools.createTreeNode = function(name , func , closeFunc)
    if imgui.treeNode(name) then
        func()
        imgui.treePop()
    else
        if closeFunc then closeFunc() end
    end
end

editorTools.createNodePopEditor = function(node)
    if not node.getName then return end
    local nodeName = node:getName()
    if not nodeName or nodeName == "" then
        nodeName = "Unknow"
    end
    if imgui.beginPopupContextItem(nodeName) then
        imgui.text(nodeName)
        node:onEditor()
        imgui.endPopup();
    end
end

editorTools.showNodeInfo = function(node)
    local nodeName = node:getName()
    if not nodeName or nodeName == "" then
        nodeName = "Unknow"
    end
    local addr = tostring(node)
    local s_index = string.find( addr, ":", 1, true )
    addr = string.sub(addr , s_index and s_index + 1 or 1)
    imgui.pushId(tonumber(addr) or 1)
    local childs = node:getChildren()
    if #childs > 0 then
        if imgui.treeNode(nodeName) then
            editorTools.createNodePopEditor(node)
            for _ , child in ipairs(childs) do
                editorTools.showNodeInfo(child)
            end
            imgui.treePop()
        else
            editorTools.createNodePopEditor(node)
        end
    else
        imgui.bullet()
        imgui.selectable(nodeName)
        editorTools.createNodePopEditor(node)
    end
    imgui.popId()
end


editorTools.showDataInfo = function(obj , args)
    args = args or {}
    local eachObj = obj
    if type(eachObj) == "userdata" then 
        editorTools.createNodePopEditor(obj)
        eachObj = tolua.getpeer(obj)
    end
    if not eachObj then return end
    local id = 1
    for key , val in pairs(eachObj) do
        id = id + 1
        imgui.pushId(id)
        local dataType = type(val)
        if dataType == "string" then
            editorTools.createNodeEditor(editorTools.Widget_Type.inputText,obj ,key  , key , key , 255)
        elseif dataType == "boolean" then
            editorTools.createNodeEditor(editorTools.Widget_Type.checkbox ,obj ,key  , key , key)
        elseif dataType == "number" then                                          
            editorTools.createNodeEditor(editorTools.Widget_Type.dragFloat ,obj ,key  , key , key)
        elseif not args.noDeep and (dataType == "table" or dataType == "userdata") then
            editorTools.createTreeNode(key , function()
                editorTools.showDataInfo(val , args)
            end , function()
                if dataType == "userdata" then
                    editorTools.createNodePopEditor(val)
                end
            end)
        elseif args.showFunc and dataType == "function" then
            imgui.text(key .. ":")
            imgui.sameLine()
            imgui.text( tostring(val) )
        end
        imgui.popId()
    end
end

editorTools.createNodeEditor = function(widgetType , node , name , getF , setF , ...)
    setF = setF or getF
    if node and node[getF] ~= nil and node[setF] ~= nil then
        local inputV
        if type(node[getF]) == "function" then
            inputV = node[getF](node)
        else
            inputV = node[getF]
        end
        if type(inputV) == "boolean" then 
            inputV = inputV and 1 or 0 
        end
        local ret , val = editorTools.createUI(widgetType , name , inputV , ...)
        if ret then
            if type(node[setF]) == "function" then
                node[setF](node , val)
            else
                node[setF] = val
            end
        end
    end
end

editorTools.createWindow = function(name , func)
--    imgui.setNextWindowSize(500 , 400)
    if not imgui.begin(name , false, {}) then 
        imgui.endToLua()
        return 
    end
    func()
    imgui.endToLua()
end

editorTools.showFrameGraph = function()
    
end

editorTools.createButton = function (path , callback)
    if imgui.imageButton(path) then
        callback()
    end
end

editorTools.createMenu = function (...)
    local args = { ... }
    if imgui.beginMenuBar() == true then
        local _createMenu
        _createMenu = function(index)
            if index < #args then
                if imgui.beginMenu(args[index]) == true then
                    _createMenu(index + 1)
                    imgui.endMenu()
                end
            else
                args[index]()
            end 
        end

        _createMenu(1)
        imgui.endMenuBar()
    end
end

editorTools.createUI = function(uiname , ...)
    local args = { ... }
    return imgui[uiname](...)
end

return editorTools