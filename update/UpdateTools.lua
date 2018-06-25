local UpdateTools = class("UpdateTools")
local Socket = require "socket"

local updateConfig = require("UpdateConfig")
local Scheduler = cc.Director:getInstance():getScheduler()

--if updateConfig.USE_UPDATE_FILE then
--    cc.FileUtils:getInstance():addSearchPath(device.writablePath.."update/res/ui/",true)
--    cc.FileUtils:getInstance():addSearchPath(device.writablePath.."update/res/",true)
--    cc.FileUtils:getInstance():addSearchPath(device.writablePath.."update/src/",true)
--    cc.FileUtils:getInstance():addSearchPath(device.writablePath.."update/",true)
--    package.path = device.writablePath .. "update/src/?.lua;" .. package.path 
--end

local g_UpdateError = nil
local timeout       = 0.5
local CHECK_SIZE      = 25
local tryTimes      = 4
local autoStartDownload = updateConfig.AUTO_DOWNLOAD
local waittingConfirm = true
local fileFolder = "files/"

local UPDATE_ERRS = {
    ERR1 = { text = "抱歉,更新出现异常,下次启动时更新" , },
    ERR2 = { text = "抱歉,文件下载失败,下次启动时更新" , },
    ERR3 = { text = "抱歉,文件更新失败,下次启动时更新" , },
    ERR4 = { text = "抱歉,文件校验出错,下次启动时更新" , },
    ERR5 = { text = "请检查网络设置" , },
    ERR6 = { text = "客户端版本太旧，请重新下载最新版" , },
}

UpdateTools.ERRORS = UPDATE_ERRS

UpdateTools.EVENTS = {
    EVENT_START = "EVENT_START",
    EVENT_FAILURE = "EVENT_FAILURE",
    EVENT_COMPLETE = "EVENT_COMPLETE",
    EVENT_PROGRESS = "EVENT_PROGRESS",
    EVENT_SHOW_NOTICE = "EVENT_SHOW_NOTICE",
    EVENT_CONFIRM_INSTALL  = "EVENT_CONFIRM_INSTALL",
    EVENT_CONFIRM_DOWNLOAD  = "EVENT_CONFIRM_DOWNLOAD",
}

UpdateTools.STATUS = {
    CHECK_VERSION = "CHECK_VERSION", -- 校验版本
    DOWNLOAD_FILE = "DOWNLOAD_FILE", -- 下载文件
    CHECK_FILE = "CHECK_FILE", -- 校验文件
    WRITE_FILE = "WRITE_FILE", -- 写入文件
    RECHECK_FILE = "RECHECK_FILE", -- 再次校验文件
    FILE_INSTALL = "FILE_INSTALL", -- 文件安装
    ALL = "ALL", -- 完成所有
}

local function checkPathEqual(path1, path2)
    path1 = string.gsub(path1, "^[%./]*" , "")
    path2 = string.gsub(path2, "^[%./]*" , "")
    return path1 == path2
end

local function MyPrint( ... )
    if DEBUG == 1 then
        print(...)
    end
end

local function MyDamp( ... )
    if DEBUG == 1 then
        log(...)
    end
end

function UpdateTools:ctor(isTest)
    local dispatcher = cc.load("event").new()
    dispatcher:bind(self)
    self.updateSev = isTest and updateConfig.UPDATE_SRV_TEST or updateConfig.UPDATE_SRV
end

function UpdateTools:delay(func,delay)
    local handler = 0
    handler = Scheduler:scheduleScriptFunc(function (dt)
        Scheduler:unscheduleScriptEntry(handler)
        func(dt)
    end,delay,false)
    return handler
end

--- 根据文件名获取父文件夹
function UpdateTools:getFolderFromName(name)
    for _sp in name:gmatch("(.+/)") do
        return _sp
    end
    return ""
end

--- 根据文件名分割文件夹返回table
function UpdateTools:splitFolderFromName(name)
    local split = {}
    for _sp in name:gmatch("(.-/)") do
        split[#split+1] = _sp
    end
    return split
end

--- 读取文件内容
function UpdateTools:readFile(path)
    local file = io.open(path, "rb")
    if file then
        local content = file:read("*all")
        io.close(file)
        return content
    end
    return nil
end

--- 删除文件(夹)
function UpdateTools:removeFile(path)
    -- MyPrint("removeFile---> "..path)
    -- require "lfs"
    os.remove(path)
    if io.exists(path) then
        local function _rmdir(path)
            local iter, dir_obj = lfs.dir(path)
            for i=1,10000 do --每个文件夹下有1W个文件和目录不太可能吧??拒绝使用[while true]
                local dir = iter(dir_obj)
                if dir == nil then break end
                if dir ~= "." and dir ~= ".." then
                    local curDir = path..dir
                    local mode = lfs.attributes(curDir, "mode") 
                    if mode == "directory" then
                        _rmdir(curDir.."/")
                    elseif mode == "file" then
                        os.remove(curDir)
                    end
                end
            end
            local succ, des = os.remove(path)
            if des then MyPrint(des) end
            return succ
        end
        _rmdir(path)
    end
    return true
end

--- 重命名文件
function UpdateTools:renameFile(path,pathNew)
    os.rename(path, pathNew)
end

--- 检查文件md5
function UpdateTools:checkFile(fileName, cryptoCode,native)
    if native then
        MyPrint("check本地File:", fileName)
    else
        MyPrint("check更新File:", fileName)
    end
    if device.platform ~= "android" and not native and not io.exists(fileName) then
--        MyPrint("checkFile ERROR NOT EXIST: "..fileName)
        return false
    end
    if cryptoCode==nil then
--        MyPrint("cryptoCode is nil")
        return true
    end
--    MyPrint("cryptoCode:", cryptoCode)
    local ms = nil
    if native and device.platform == "android" then
        MyPrint("使用java")
        ms = DeviceTool:getAssetsFileMD5(fileName)
    else
        -- MD5:File是会无视更新路径进行读取文件
        ms = MD5:File(fileName)
    end
    MyPrint("crypto.md5:", ms)
    if ms==cryptoCode then
        return true
    end
    return false
end

--- 数据写入文件
function UpdateTools:writeFile(filename,data)
    -- MyPrint("UpdateTools:writeFile: "..filename)
    local ok = io.writefile(filename, data)
    return ok
end

--- 检查并创建文件夹
function UpdateTools:checkDirOK( path )
    -- require "lfs"
    local oldpath = lfs.currentdir()
    -- MyPrint("old path------> "..oldpath)
    if lfs.chdir(path) then
        lfs.chdir(oldpath)
        MyPrint("path check OK------> "..path)
        return true
    end
    if lfs.mkdir(path) then
        MyPrint("path create OK------> "..path)
        return true
    else
        MyPrint("建文件夹失败"..path)
    end
    return false
end

--- 列举文件夹内所有文件
function UpdateTools:listFiles(rootpath,checkPath)
    local files = self:listFiles_(rootpath..checkPath,{})
    for i,v in ipairs(files) do
        files[i] = checkPath..string.sub(v,string.len(rootpath..checkPath)+2,-1)
    end
    return files
end

--- 列举文件夹内所有文件(递归用)
function UpdateTools:listFiles_(rootpath,pathes)
    -- require "lfs"
    ret, files, iter = pcall(lfs.dir, rootpath)
    if ret == false then
        return pathes
    end
    for entry in files, iter do
        local next = false
        if entry ~= '.' and entry ~= '..' then
            local path = rootpath .. '/' .. entry
            local attr = lfs.attributes(path)
            if attr == nil then
                next = true
            end

            if next == false then 
                if attr.mode == 'directory' then
                    self:listFiles_(path, pathes)
                else
                    table.insert(pathes, path)
                end
            end
        end
        next = false
    end
    return pathes
end

function UpdateTools:init()
    g_UpdateError = nil
    if not table.indexof(updateConfig.UPDATE_TARGET, device.platform) then
        self:runApp()
        return
    end
    self.allSize = 0 --算出来的总大小
    self.finishSize = 0 --已经下载好文件大小
    self.serverPath = self.updateSev .. "/" .. (updateConfig.UPDATE_FOLD or device.platform) .. "/" 
    self.useBackup = updateConfig.USE_BACKUP 
    self.autoRemoveFile = updateConfig.AUTO_REMOVE_FILE 
    self.list_md5 = "listmd5.xml"
    self.list_filename = "updatelist.xml"
    self.downList = {} --已经下好的文件
    self.backupList = {} --写文件用于覆盖的备份
    self.filesInServer = {}
    
    self.updated_DirName = "update/"
    self.updatePath = device.writablePath..self.updated_DirName --更新资源路径
    self:checkDirOK(self.updatePath)  
    self:start()  
end

--- 检查本地原生更新
function UpdateTools:checkNewInstall()
    local nativeVerFile = self.updatePath .. "NativeVersion"
    local nativeVer = "-1"
    local readVerFile = function()
        nativeVer = dofile(nativeVerFile)
    end
    pcall(readVerFile)
    if nativeVer ~= DeviceTool:getVersion() then
        MyPrint("检测到版本不一致可能是Native更新应用,删除旧的脚本资源: "..nativeVer.."  "..DeviceTool:getVersion())
        local ver = "return \""..DeviceTool:getVersion().."\""
        self:writeFile(nativeVerFile, ver)
        self:removeFile(self.updatePath.."res/")
        self:removeFile(self.updatePath.."src/")
    end
end

function UpdateTools:getVersion()
    return DeviceTool:getVersion()
end

function UpdateTools:runApp()
    if g_UpdateError then
        self:dispatchEvent({name = self.EVENTS.EVENT_FAILURE, text = g_UpdateError.text })
        return
    end
    if self.nativeUpdateFile then
        self:dispatchEvent({name = self.EVENTS.EVENT_FAILURE, text = UPDATE_ERRS.ERR6.text })
        return
    end
    -- 清理已加载资源
    for k,v in pairs(package.loaded) do
        if string.find(k, "app.") == 1 or string.find(k, "cocos.") == 1 or string.find(k, "packages.") == 1 then
            package.loaded[k] = nil
        end
    end
    cc.FileUtils:getInstance():purgeCachedEntries()
    self:dispatchEvent({name = self.EVENTS.EVENT_COMPLETE, type = self.STATUS.ALL })
end

function UpdateTools:start()
    self:dispatchEvent({name = self.EVENTS.EVENT_START, type = self.STATUS.CHECK_VERSION })
    self.localListFile =  self.updatePath..self.list_filename
    self.fileList = nil
    self:checkNewInstall()
    self.requestCount = 0
    if updateConfig.USE_LIST_MD5 then
        self.requesting = self.list_md5 -- 通过更新文件md5,减少检测拉取文件时间
    else
        self.requesting = self.list_filename -- 记录正在更新的步骤
    end
    self.dataRecv = nil
    self.firstReq = self:requestFromServer(self.requesting,timeout)
end

function UpdateTools:update(dt)
    if self.dataRecv then
        if self.requesting == self.list_md5 then
            local md5 = self.dataRecv
            MyPrint("md5: "..md5)
            self.dataRecv = nil
            local readListMD5 = function()
                self.listMD5 = dofile(self.updatePath..self.list_md5)
            end
            pcall(readListMD5)
            if md5 == self.listMD5 then
                MyPrint("Lua版本相同跳过更新")
                self:runApp() --没有更新的东西了
            else
                self.requesting = self.list_filename
                if io.exists(self.localListFile) and MD5:File(self.localListFile) == md5 then
                    MyPrint("使用本地列表")
                    self.dataRecv = self:readFile(self.localListFile)
                else
                    MyPrint("使用服务器列表")
                    self:requestFromServer(self.requesting)
                end
                return
            end
        end
        if self.requesting == self.list_filename then
            self:requestingList()
            return
        end
        if self.requesting == "files" then
            self:requestingFiles()
            return
        end
    end
    if self.downloader then
        self.downloader()
    end
    if self.requesting == "checking" then
        if self.checker then
            self.checker()
        end
    end
    if self.requesting == "rechecking" then
        if self.rechecker then
            self.rechecker()
        end
    end
    if self.requesting == "write" then
        self:requestingWrite()
    end
    if self.requesting == "end" then
        self.requesting = nil
        self:endProcess()
    end
end

--- 检查本地存储空间是否足够
function UpdateTools:checkFreeStorage(args)
    local free = DeviceTool:getFreeStorage()
    if free < 0 then
        return true
    end
    if self.allSize > free then
        local params = {}
        params.buttons = {{titile = args.isForce and "退出游戏" or "知道了" , handler = function()
            if args.isForce then
                self:exit()    
            else
                self:cancel()
            end
        end}}
        params.text = "抱歉，内存不足，无法下载！\n请清理内存空间！"
        if not args.isForce then
            tip = tip .. "下次重启可启动更新！"
        end
	    params.noShowClose = true
	    params.fontSize= 30
        viewMgr:oneAlert(params)
        return false
    end
    return true
end

--- 点击确认更新
function UpdateTools:confirm()
    MyPrint("确认更新")
    self:dispatchEvent({name = self.EVENTS.EVENT_START, type = self.STATUS.DOWNLOAD_FILE })
    self:reqNextFile()
end

function UpdateTools:exit()
    MyPrint("退出应用")
    cc.Director:getInstance():endToLua()
    if device.platform == "windows" or device.platform == "mac" or device.platform == "ios" then
        os.exit()
    end
end

--- 点击取消更新
function UpdateTools:cancel()
    MyPrint("取消更新")
    xpcall(function ()
        self:fixEnd()
    end,__G__TRACKBACK__)
    self:runApp()
end

--- 列表文件解析
function UpdateTools:requestingList()
    MyPrint("保存文件列表:" .. self.localListFile)
    self:writeFile(self.localListFile, self.dataRecv)
    self.dataRecv = nil
    local readListFile = function()
        self.fileList = dofile(self.localListFile)
    end
    pcall(readListFile)
    if self.fileList==nil then
        MyPrint(self.localListFile..": Open UpdateList Error!")
        g_UpdateError = UPDATE_ERRS.ERR1
        self.requesting = "end"
        return
    elseif type(self.fileList.fix) == "function" then
        self.fileList.fix(self)
    end
    local fixNeedReturn = false
    xpcall(function ()
        fixNeedReturn = self:fixBegin()
    end,__G__TRACKBACK__)
    -- dump(self.fileList)
    if fixNeedReturn == true then -- 修复更新程序后需要重新来过,注意需要把这个值设为false,否则一直循环
        self.requestCount = 0
        if updateConfig.USE_LIST_MD5 then
            self.requesting = self.list_md5 -- 通过更新文件md5,减少检测拉取文件时间
        else
            self.requesting = self.list_filename -- 记录正在更新的步骤
        end
        self.dataRecv = nil
        self.firstReq = self:requestFromServer(self.requesting,10)
        self.newUrl = false
        return
    end
    self.numFileCheck = 0
    self.allSize = 0 --算出来的总大小
    self.finishSize = 0 --已经下载好文件大小
    self.requesting = "files"

    local nativeVer = DeviceTool:getVersion()
    local serverVer = {nativeVer}

    if type(self.fileList) == "table" then
        serverVer = self.fileList.ver or nativeVer
        if type(serverVer) == "string" then
            MyPrint("nativeVer =" .. nativeVer .. ";serverVer =" .. serverVer)
            serverVer = {serverVer}
        else
            MyPrint("nativeVer ="..nativeVer .. ";serverVer :")
            for i,v in ipairs(serverVer) do
                MyPrint(v)
            end
        end
    end

    local notice  = self.fileList.notice
    local isForce = self.fileList.isForce == true
    -- if serverVer ~= nativeVer then --这里会修改覆盖原来的Force下载列表,请注意!!!
    if not table.indexof(serverVer, nativeVer) then --这里会修改覆盖原来的Force下载列表,请注意!!!
        if device.platform == "android" then
            self.fileList.force = {{
                file = self.fileList.path,
                size = self.fileList.size,
                code = self.fileList.code,
                time = self.fileList.time or 17,
            }}
            tryTimes = 1
        elseif device.platform == "ios" then
            self.fileList.force = {} --ios因为直接上AppStore这里清空下载列表
        end

        notice  = self.fileList.notice
        isForce = self.fileList.isForce == true
        if self.fileList.path and self.fileList.path ~= "" then
            self.nativeUpdateFile = self.fileList.path
        else
            g_UpdateError = UPDATE_ERRS.ERR6
        end
    end
    self:dispatchEvent({name = self.EVENTS.EVENT_COMPLETE, type = self.STATUS.CHECK_VERSION })
    self:checkListFiles()
--    if self:checkListFiles() == true then
--        self:createDialog({notice = notice,isForce = isForce})
--    else
--        self.requesting = "end"
--    end
end

function UpdateTools:createDialog(args)
    local showConfirm =function()
        if device.platform == "android" and args.isForce == false then
            self:delay(function()
                display.newLayer():onKeypad(function (event)
                    if event.key == "back" then
                        self:cancel()
                    end
                end):enableKeypad(true):addTo(viewMgr._infoLayer)-- FIXME 处理返回键
            end , 0)
        end
        if self:checkFreeStorage(args) then
            if autoStartDownload then
                self:confirm()
            else
                self:dispatchEvent({name = self.EVENTS.EVENT_CONFIRM_DOWNLOAD, size = self.allSize, func = function(ret)
                    if ret then
                        self:confirm()
                    else
                        if args.isForce then
                            self:exit()
                        else
                            self:cancel()
                        end
                    end
                end })
            end
        end
    end
    if args.notice == nil or args.notice == "" then --没有弹框
        showConfirm()
        return
    else
        self:dispatchEvent({name = self.EVENTS.EVENT_SHOW_NOTICE, text = args.notice,func = function(ret)
            if ret then
                if self:checkFreeStorage(args) then
                    self:confirm()
                end
            else
                if args.isForce then
                    self:exit()
                else
                    self:cancel()
                end
            end
        end })
    end
    
end

--- 更新每个文件
function UpdateTools:requestingFiles()
    local fn = self.updatePath..self.curStageFile.file..".upd"
    self.finishSize = self.finishSize + self.curStageFile.size
    if not self:checkDirOK(device.writablePath..self.updated_DirName..self:getFolderFromName(self.curStageFile.file)) then
        local dir = ""
        local folders = self:splitFolderFromName(self.curStageFile.file)
        for i=1,#folders do
            dir = dir .. folders[i]
            self:checkDirOK(device.writablePath..self.updated_DirName..dir)
        end
    end
    
    local ok = self:writeFile(fn, self.dataRecv)
    local ok = true
    self.dataRecv = nil
    if ok == false then
        g_UpdateError = UPDATE_ERRS.ERR3
        self:runApp()
        return
    end
    if self:checkFile(fn, self.curStageFile.code) then
        table.insert(self.downList, fn)
        self:reqNextFile()
    else
        g_UpdateError = UPDATE_ERRS.ERR4
        self:runApp()
    end
end

--- 写入文件
function UpdateTools:requestingWrite()
    if #self.downList == 0 then
        self:onFinish()
        return
    end
    local udpFile = self.downList[1]
    table.remove(self.downList,1);

    local data=self:readFile(udpFile)
    local fn = string.sub(udpFile, 1, -5)
    self:backupWrite(fn)
    local ok = self:writeFile(fn, data)
    -- ok = false --test faile
    if ok == false then
        g_UpdateError = UPDATE_ERRS.ERR3 --其实这里一旦发现写文件失败要把之前的都还原掉啊...
        self:recoverBackup()
        self:runApp()
        return
    end
    self:removeFile(udpFile)
end

--- 备份覆盖的文件
function UpdateTools:backupWrite(filename) --也有可能备份时刚好容量不足,未处理!!
    if not self.nativeUpdateFile and self.useBackup then
        table.insert(self.backupList, filename..".bak")
        if io.exists(filename) then
            self:renameFile(filename, filename..".bak")
        end
    end
end

--- 还原覆盖的文件
function UpdateTools:recoverBackup() --也有可能恢复的时候写失败,未处理!!
    if self.nativeUpdateFile then
        return
    end
    if self.useBackup then
        for i,v in ipairs(self.backupList) do
            if io.exists(v) then
                self:renameFile(v, string.sub(v, 1, -5))
            else
                self:removeFile(string.sub(v, 1, -5))
            end
        end
    else
        self:delay(function ()
            cc.Director:sharedDirector():endToLua()
            if device.platform == "windows" or device.platform == "mac" or device.platform == "ios" then
                os.exit()
            end
        end,2)
    end
end

--- 更新结束环节,重新检查文件
function UpdateTools:endProcess() --这是有检查文件的
    MyPrint("----------------------------------------UpdateTools:endProcess")
    local checkOK = true
    self:dispatchEvent({name = self.EVENTS.EVENT_START, type = self.STATUS.RECHECK_FILE })
    self.requesting = "rechecking"
    self.recheck_index = 0
    self:checkProgressing(0)
    self.rechecker = function()
        for i = 1, CHECK_SIZE do
            self.recheck_index = self.recheck_index + 1
            if checkOK and self.fileList and self.fileList.force and self.recheck_index <= #self.fileList.force then
                self:checkProgressing(self.recheck_index)
                local v = self.fileList.force[self.recheck_index]
                MyPrint("检查文件"..v.file.."  "..v.code)
                -- 这个时候一定是下载在更新目录才对
                if not self:checkFile(self.updatePath..v.file, v.code) then
                    MyPrint("----------------------------------------Check Files Error")
                    g_UpdateError = UPDATE_ERRS.ERR4;
                    checkOK = false
                end
            else
                xpcall(function ()
                    self:fixEnd()
                end,__G__TRACKBACK__)
                self:checkProgressing(self.fileList and self.fileList.force and #self.fileList.force or 0)
                self:dispatchEvent({name = self.EVENTS.EVENT_COMPLETE, type = self.STATUS.RECHECK_FILE })
                self.requesting = nil
                self.recheck_index = nil
                self.rechecker = nil
                if checkOK and self.fileList and type(self.fileList.remove) == "table" then
                    for i,v in ipairs(self.fileList.remove) do
                        MyPrint("removeFile from List :"..self.updatePath..v)
                        self:removeFile(self.updatePath..v)
                    end
                end

                if checkOK and self.autoRemoveFile then
                    local files = self:listFiles(self.updatePath,"src/")
                    table.merge(files, self:listFiles(self.updatePath,"res/"))
                    for i,v in ipairs(files) do
                        if not self.filesInServer[v] then
                            MyPrint("removeFile from Auto :"..self.updatePath..v)
                            self:removeFile(self.updatePath..v)
                        end
                    end
                end
                MyPrint("结束更新跳到游戏里去了")
                if self.nativeUpdateFile and g_UpdateError == nil then
                    local isForce = false
                    if self.fileList and type(self.fileList[device.platform]) == "table" then
                        isForce = self.fileList[device.platform].isForce == true
                    end
                    -- if isForce then
                    if isForce and device.platform ~= "ios" then
                        self:dispatchEvent({name = self.EVENTS.EVENT_CONFIRM_INSTALL, func = function(ret)
                            if ret then
                                self:callNativeInstall()
                                self:exit()
                            else
                                if isForce then
                                    self:exit()
                                else
                                    self:cancel()
                                end
                            end
                        end })
                        return
                    end
                end
                for i,v in ipairs(self.backupList) do
                    self:removeFile(v)
                end
                self:dispatchEvent({name = self.EVENTS.EVENT_COMPLETE, type = self.STATUS.RECHECK_FILE })
                if self.requesting ~= self.list_filename and self.requesting ~= self.list_md5 and g_UpdateError == nil and updateConfig.USE_LIST_MD5 and io.exists(self.localListFile) and not self.nativeUpdateFile then
                    local md5Save = "return \""..MD5:File(self.localListFile).."\""
                    MyPrint("保存本地的md5校验和" , self.localListFile , md5Save)
                    self:writeFile(self.updatePath..self.list_md5, md5Save)
                end
                self:runApp()
                break
            end
        end
    end
end

--- 通过更新文件修复更新功能
function UpdateTools:fixBegin()
    -- MyPrint("还是原来的味道")
    return false
end

--- 通过更新文件修复更新功能
function UpdateTools:fixEnd()
end
---------------------------
-- 如果更换了下载重写这两个方法
---------------------------

--  http://blog.csdn.net/yifan_lym/article/details/49588669
function UpdateTools:makeURL(filename)
    return self.serverPath..filename:gsub(" ", "%%20").."?v="..os.time() --后面加个参数是为了防止CDN缓存问题
end

local reqStr = "GET %s HTTP/1.1\r\nAccept:text/html,application/xhtml+xml,application/xml"..
";q=0.9,image/webp,*/*;q=0.8\r\nUser-Agent:Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/53"..
"7(KHTML, like Gecko) Chrome/47.0.2526Safari/537.36\r\nHost:%s\r\nConnection:close\r\n\r\n"

function UpdateTools:onDownloadErr(filename, waittime)
    if self.errorDownloadFile ~= filename then
        self.errorDownloadTyr = 1
        self.errorDownloadFile = filename
        self:requestFromServer(filename, waittime)
        MyPrint("文件请求失败,第一次尝试重新请求该文件")
        return
    elseif self.errorDownloadTyr < tryTimes then
        self.errorDownloadTyr = self.errorDownloadTyr + 1
        self:requestFromServer(filename, waittime)
        MyPrint("文件请求失败,重试: "..self.errorDownloadTyr)
        return
    end
    if self.requesting ~= self.list_filename and self.requesting ~= self.list_md5 then
        g_UpdateError = UPDATE_ERRS.ERR2
    else
        g_UpdateError = UPDATE_ERRS.ERR5
    end
    self.downloader = nil
    self:runApp()
end

--- 检查更新列表哪些文件要更新
function UpdateTools:checkListFiles()
    local needRequsetFiles = {}
    self.requesting = "checking"
    self.checkIndex = 1
    self:dispatchEvent({name = self.EVENTS.EVENT_START, type = self.STATUS.CHECK_FILE })
    self:checkProgressing(0)
    self.checker = function()
        for i = 1, CHECK_SIZE do
            self.checkIndex = self.checkIndex + 1
            if self.fileList and self.fileList.force and self.checkIndex <= #self.fileList.force then
                local v = self.fileList.force[self.checkIndex]
                self.filesInServer[v.file] = 1
                local need = true
                --和包里面的文件比一下
                if self:checkFile(v.file, v.code,true) then
                    need = false
                    -- 本地有了并且一致还要删掉更新文件夹的,因为有可能改了又还原,这个情况不用下载
                    self:removeFile(self.updatePath..v.file)
                end
                -- 和本地文件比
                if need and self:checkFile(self.updatePath..v.file, v.code) then
                    need = false
                end
                if need then
                    needRequsetFiles[#needRequsetFiles+1] = v
                    self.allSize = self.allSize+v.size
                end
                self:checkProgressing(self.checkIndex)
            else
                self:dispatchEvent({name = self.EVENTS.EVENT_COMPLETE, type = self.STATUS.CHECK_FILE })
                self.fileList.force = needRequsetFiles
                if DEBUG > 0 then
                    for i,v in ipairs(needRequsetFiles) do
                        MyPrint("File "..i..": path="..v.file.."\n".." code="..v.code.." size="..v.size)
                    end
                end
                self.checker = nil
                self.checkIndex = nil
                if #self.fileList.force > 0 then
                    self.requesting = "files"
                    self:createDialog({notice = self.fileList.notice ,isForce = self.fileList.isForce == true})
                else
                    self.requesting = "end"
                end
                break
            end
        end
    end
end

--- 调用原生应用安装
function UpdateTools:callNativeInstall()
    self:dispatchEvent({name = self.EVENTS.EVENT_START, type = self.STATUS.FILE_INSTALL })
    if device.platform == "android" then
        DeviceTool:install(self.updatePath..self.nativeUpdateFile)
    elseif device.platform == "ios" then
        UpdateTools.url = self.nativeUpdateFile -- FIXME 现在的代码入侵太多了
        DeviceTool:install(self.nativeUpdateFile)
    end
end

--- 进入更新列表文件环节
function UpdateTools:updateFiles()
    self:progressing(0)
    self.requesting = "write"
end

--- 更新结束
function UpdateTools:onFinish()
    self:dispatchEvent({name = self.EVENTS.EVENT_COMPLETE, type = self.STATUS.DOWNLOAD_FILE })
    if self.nativeUpdateFile then
        if device.platform == "android" or device.platform == "mac" then
            local downPath = self.updatePath..self.nativeUpdateFile
            local suffix = string.sub(downPath, -3, -1)
            if string.lower(suffix) == "apk" then
                -- if self.m_btnOK then
                --     self.m_btnOK:removeAllEventListenersForEvent(self.m_btnOK.CLICKED_EVENT)
                --     self.m_btnOK:addClickEventListener(function(event)
                        -- self:callNativeInstall()
                    -- end)
                -- end
                self:callNativeInstall()
            end
        elseif device.platform == "ios" then
            -- self.m_btnOK:removeAllEventListenersForEvent(self.m_btnOK.CLICKED_EVENT)
            -- self.m_btnOK:addClickEventListener(function(event)
                -- self:callNativeInstall()
            -- end)
            self:callNativeInstall()
        end
        self.fileList.force = {}
    end
    self.requesting = "end"
end

--- 请求下一个文件
function UpdateTools:reqNextFile()
    self.numFileCheck = self.numFileCheck+1
    self.curStageFile = self.fileList.force[self.numFileCheck]
    if self.curStageFile and self.curStageFile.file then
        MyPrint("请求下一个文件:"..self.curStageFile.file)
        -- 这里没必要再去检查包里的文件。之前已检查过所有文件的包文件了。所以能运行到这里一定是不存在的
--        if not checkPathEqual(cc.FileUtils:getInstance():fullPathForFilename(self.curStageFile.file) , self.curStageFile.file) then
--            if self:checkFile(self.curStageFile.file, self.curStageFile.code,true) then
--                self:reqNextFile()
--                return
--            end
--        end
        local fn = self.updatePath..self.curStageFile.file --再检查Lua更新的有没
        if self:checkFile(fn, self.curStageFile.code) then
            self:reqNextFile()
            return
        end
        fn = fn..".upd"
        if self:checkFile(fn, self.curStageFile.code) then --这种情况是下载资源到一半游戏关掉的
            table.insert(self.downList, fn)
            self.finishSize = self.finishSize + self.curStageFile.size
            self:reqNextFile()
            return
        end
        self:requestFromServer(fileFolder .. self.curStageFile.file , self.curStageFile.time)
        return
    end
    self:updateFiles()
end

function UpdateTools:requestFromServer(filename, waittime)
    waittime = waittime or timeout
    local url = self:makeURL(filename)
    for host,path in url:gmatch("//(.-)(/.+)") do
        local c = Socket.tcp()
        c:settimeout(0.2)
        local addr = string.split(host , ":")
        MyPrint(addr[1] , addr[2])
        c:connect(addr[1],tonumber(addr[2]) or 80)
        local f = io.open(device.writablePath.."UpdateDownloadData","w+b")
        local ReadHead  = false
        c:send(string.format(reqStr, path ,host))
        local RecvTime = Socket.gettime()
        local WriteSize = 0
        local RecvData = ""
        local lastSize = 0
        MyPrint("开始请求: "..url.."  "..RecvTime)
        MyPrint(filename)
        self.downloader = function ()
            local data,status,partial = c:receive(10240)
            if data and partial then data = data .. partial end
            data = partial or data
            if not ReadHead and data:find("\n\r") then
                for code in data:gmatch(" (.-) ") do
                    MyPrint("下载 code: "..code)
                    if tonumber(code) ~= 200 then
                        c:shutdown()
                        self:onDownloadErr(filename, waittime)
                        return
                    end
                    break
                end
                ReadHead = true
                data = data:sub(data:find("\n\r")+3,-1)
            end
            f:write(data)

            if data and data:len() > 0 then
                WriteSize = WriteSize + data:len()
                RecvTime = Socket.gettime()
            end

            self:progressing(WriteSize)
    
            if status == "timeout" then
                if Socket.gettime() - RecvTime > waittime then
                    MyPrint("Socket 下载超时: "..Socket.gettime())
                    c:shutdown()
                    f:close()
                    self:removeFile(device.writablePath.."UpdateDownloadData")
                    self:onDownloadErr(filename, waittime)
                end
                return
            end
            if status == "closed" then
                -- self.dataRecv = RecvData
                f:close()
                f = io.open(device.writablePath.."UpdateDownloadData","rb")
                self.dataRecv = f:read("*a")
                c:shutdown()
                f:close()
                self:removeFile(device.writablePath.."UpdateDownloadData")
                self.downloader = nil
                return
            end

            if status and status:find("not connected") then
                MyPrint("异常关闭了")
                c:shutdown()
                f:close()
                self:removeFile(device.writablePath.."UpdateDownloadData")
                self:onDownloadErr(filename, waittime)
                return
            end
        end
        return c
    end
end

--- 更新进度条
function UpdateTools:progressing(size)
    local percent = self.allSize > 0 and (self.finishSize+size)/self.allSize or 0
    self:dispatchEvent({name = self.EVENTS.EVENT_PROGRESS, percent = percent , value = self.finishSize+size , total = self.allSize , type = "DOWNLOAD"})
end

function UpdateTools:checkProgressing(size)
    local total = self.fileList and #self.fileList.force > 0 and #self.fileList.force or 0
    local percent = total > 0 and size/total or 0
    self:dispatchEvent({name = self.EVENTS.EVENT_PROGRESS, percent = percent , value = size , total = total , type = "CHECK"})
end

return UpdateTools