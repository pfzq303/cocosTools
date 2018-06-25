local cfg = {
    android = {
        -- UPDATE_TARGET = { },
--        UPDATE_SRV = "http://192.168.1.160:9001", 
    },
    ios = {
		-- UPDATE_TARGET = { },
    },
    windows = {
--        UPDATE_TARGET = { "windows" },
        UPDATE_SRV = "http://192.168.1.157:9001", 
    },
    default = {
        AUTO_DOWNLOAD = false;
        USE_UPDATE_FILE = true, -- 是否启动更新文件
        UPDATE_TARGET = { "ios" , "android" }, -- 更新的目标平台
        UPDATE_SRV = "http://192.168.1.157:9001", -- 更新服务器
        UPDATE_SRV_TEST = "http://192.168.1.157:9001/update_test", -- 测试的更新服务器
        USE_BACKUP = false, --写文件失败是使用备份恢复(true)还是关闭app(false)
        AUTO_REMOVE_FILE = true, --自动检查删除多余的文件
        USE_LIST_MD5 = true, -- 通过更新文件md5,减少检测拉取文件时间
    },
}
local ret = {}
setmetatable(ret, {
    __index = function(myTable, key)
        if cfg[device.platform] and cfg[device.platform][key] ~= nil then
            return cfg[device.platform][key]
        end
        return cfg.default[key]
    end,
    __newindex = function()
        error("updateConfig is readonly!")
    end
})

return ret