#! /usr/local/bin/python python
#-*- encoding: utf-8 -*-
import sys
reload(sys)
sys.setdefaultencoding('utf-8')
#引入wx模块
import wx
import hashlib
import os
import os.path
import re
import subprocess
import platform
import shutil
import json
import zipfile
import xxtea


if platform.system() == "Windows":
    from _winreg import *

space = ' '
leftP = 10
cellH = 30


ScriptPath = os.path.split( os.path.realpath( sys.argv[0] ) )[0]
RootDir = ScriptPath + "/../../../"
CheckDirs      = ["res", "src"]
ExceptFile     = []
APKPath        = "GameFramware.apk"
IPAPath        = "GameFramware.ipa"
ProjectAndroid = RootDir + "frameworks/runtime-src/proj.android/"
ProjectIOS     = RootDir + "frameworks/runtime-src/proj.ios_mac/"
CompareDir     = RootDir + "compares/LastNativeFiles/"
RemoveDir      = RootDir + "compares/remove/"
SilentDir      = RootDir + "compares/silent/"



ConfigJson          = "config.json"
ConfigLuaNotice     = "LuaNotice"
ConfigAndroidNotice = "AndroidNotice"
ConfigIOSNotice     = "IOSNotice"
ConfigLuaForce      = "LuaForce"
ConfigAndroidForce  = "AndroidForce"
ConfigIOSForce      = "IOSForce"
ConfigBuildAndroid  = "BuildAndroid"
ConfigBuildIOS      = "BuildIOS"
ConfigCDNPath       = "CDNPath"
ConfigXXTEA         = "XXTEA"
def zip_dir(dirname, zipfilename):
    filelist = []
    if os.path.isfile(dirname):
        filelist.append(dirname)
    else:
        for root, dirs, files in os.walk(dirname):
            for name in files:
                filelist.append(os.path.join(root, name))
    zf = zipfile.ZipFile(zipfilename, "w", zipfile.zlib.DEFLATED)
    for tar in filelist:
        arcname = tar[len(dirname):]
        #print arcname
        zf.write(tar, arcname)
    zf.close()

def unzip_file(zipfilename, unziptodir):
    if not os.path.exists(unziptodir):
        os.mkdir(unziptodir, 0777)
    zfobj = zipfile.ZipFile(zipfilename)
    for name in zfobj.namelist():
        name = name.replace('\\', '/')
        if name.endswith('/'):
            os.mkdir(os.path.join(unziptodir, name))
        else:
            ext_filename = os.path.join(unziptodir, name)
            ext_dir = os.path.dirname(ext_filename)
            if not os.path.exists(ext_dir):
                os.mkdir(ext_dir, 0777)
            outfile = open(ext_filename, 'wb')
            outfile.write(zfobj.read(name))
            outfile.close()
# End Define

endstring = {'.lua', '.mp3', '.png', '.jpg', '.plist', '.ccreator'}
# Define Some Functions
def EndWith(s):
    array = map(s.endswith, endstring)
    if True in array:
        return True
    else:
        return False
pass


#定义一个wx 的class
class PackageTools(wx.Frame):
    def __init__(self):
        self.OnEnter()
        wx.Frame.__init__(self, None, -1, "打包工具V1.0", size=(930, 430))
        panel = wx.Panel(self)
        #Lua更新配置
        wx.StaticText(panel, -1, label='Lua更新配置:', pos=(leftP, leftP), size=(-1, -1))
        self.lForceBox = wx.CheckBox(panel, -1, "勾选强制更新", (leftP, leftP+cellH), size=(-1, -1))
        wx.StaticText(panel, -1, label='更新弹框内容:', pos=(leftP, leftP+cellH*2), size=(-1, -1))
        self.lNoticeCtrl = wx.TextCtrl(panel, -1, value='', pos=(100, leftP+cellH*2), size=(800, 20))
        self.lForceBox.SetValue(self.config.get(ConfigLuaForce))
        self.lNoticeCtrl.SetValue(self.config.get(ConfigLuaNotice))
        #Android更新配置
        wx.StaticText(panel, -1, label='Android更新配置:  Ver='+self.aVerValue, pos=(leftP, leftP+cellH*4), size=(-1, -1))
        self.aForceBox = wx.CheckBox(panel, -1, "勾选强制更新", (leftP, leftP+cellH*5), size=(-1, -1))
        wx.StaticText(panel, -1, label='更新弹框内容:', pos=(leftP, leftP+cellH*6), size=(-1, -1))
        self.aNoticeCtrl = wx.TextCtrl(panel, -1, value='', pos=(100, leftP+cellH*6), size=(800, 20))
        self.aForceBox.SetValue(self.config.get(ConfigAndroidForce))
        self.aNoticeCtrl.SetValue(self.config.get(ConfigAndroidNotice))
        #iOS更新配置
        wx.StaticText(panel, -1, label='iOS更新配置:  Ver='+self.iVerValue, pos=(leftP, leftP+cellH*8), size=(-1, -1))
        self.iForceBox = wx.CheckBox(panel, -1, "勾选强制更新", (leftP, leftP+cellH*9), size=(-1, -1))
        wx.StaticText(panel, -1, label='更新弹框内容:', pos=(leftP, leftP+cellH*10), size=(-1, -1))
        self.iNoticeCtrl = wx.TextCtrl(panel, -1, value='', pos=(100, leftP+cellH*10), size=(800, 20))
        self.iForceBox.SetValue(self.config.get(ConfigIOSForce))
        self.iNoticeCtrl.SetValue(self.config.get(ConfigIOSNotice))
        #其他UI
        self.makeButton = wx.Button(panel, -1, label='生成更新文件', pos=(800, 350), size=(-1, 30))
        self.logCtrl = wx.TextCtrl(panel, style=wx.TE_MULTILINE | wx.TE_READONLY, pos=(930, leftP), size=(300, 370))
        self.compareBox = wx.CheckBox(panel, -1, "更新Lua比对资源", (680, 360), size=(-1, -1))
        self.compareBox.Enable(True == self.config.get(ConfigIOSForce) and True == self.config.get(ConfigAndroidForce))
        # self.compareBox.SetValue(True == self.config.get(ConfigIOSForce) and True == self.config.get(ConfigAndroidForce))

        wx.StaticText(panel, -1, label='CDN文件夹:', pos=(leftP, 360), size=(-1, -1))
        self.cdnPathCtrl = wx.TextCtrl(panel, -1, value='', pos=(100, 358), size=(370, 20))
        self.cdnPathCtrl.SetValue(self.config.get(ConfigCDNPath))

        self.buildAndroidBox = wx.CheckBox(panel, -1, "生成apk", (500, 360), size=(-1, -1))
        self.buildAndroidBox.SetValue(self.config.get(ConfigBuildAndroid))

        self.buildIOSBox = wx.CheckBox(panel, -1, "生成ipa", (590, 360), size=(-1, -1))

        # self.ignorComp = wx.CheckBox(panel, -1, "生成全文件MD5", (100, leftP), size=(-1, -1))
        self.xxteaBox = wx.CheckBox(panel, -1, "脚本加密", (100, leftP), size=(-1, -1))
        self.xxteaBox.SetValue(self.config.get(ConfigXXTEA))
        # self.force2silent = wx.CheckBox(panel, -1, "本次所有更新转为静默", (230, leftP), size=(-1, -1))
        # self.repatriateButton = wx.Button(panel, -1, label='回滚上个版本', pos=(400, 0), size=(-1, 30))

        if platform.system() == "Windows":
            self.buildIOSBox.SetValue(False)
            self.buildIOSBox.Enable(False)
        else:
            self.buildIOSBox.SetValue(self.config.get(ConfigBuildIOS))

        self.Bind(wx.EVT_BUTTON, self.OnClick, self.makeButton)
        self.Bind(wx.EVT_CHECKBOX, self.OnCheck)
        self.Bind(wx.EVT_TEXT, self.OnTextChange)

        # self.OnSvnAddAll()
    def OnEnter(self):
        self.GetNativeVer()

        self.config = {}
        self.config[ConfigLuaNotice] = ""
        self.config[ConfigAndroidNotice] = ""
        self.config[ConfigIOSNotice] = ""
        self.config[ConfigCDNPath] = ""
        self.config[ConfigLuaForce] = False
        self.config[ConfigAndroidForce] = False
        self.config[ConfigIOSForce] = False
        self.config[ConfigBuildAndroid] = True
        self.config[ConfigBuildIOS] = True

        if os.path.isfile(ConfigJson):
            self.config = json.load(open(ConfigJson, 'r'))

    def OnClick(self):
        pass
    def OnCheck(self):
        pass

    def GetNativeVer(self):
        manifest = open(ProjectAndroid+"AndroidManifest.xml", "rb")
        for line in manifest:
            if "android:versionName" in line:
                search = re.search(r'"(.*)"', line, re.M | re.I)
                if search:
                    self.aVerValue = search.group(1)
                else:
                    self.aVerValue = "ERROR"
        manifest.close()

        plist = open(ProjectIOS+"ios/Info.plist", "rb")
        nextLine = False
        for line in plist:
            if True == nextLine:
                search = re.search(r'>(.*)<', line, re.M | re.I)
                if search:
                    self.iVerValue = search.group(1)
                else:
                    self.iVerValue = "ERROR"
                break
            if "CFBundleShortVersionString" in line:
                nextLine = True
        plist.close()
    pass
app = wx.PySimpleApp()
PackageTools().Show()
#主循环
app.MainLoop()