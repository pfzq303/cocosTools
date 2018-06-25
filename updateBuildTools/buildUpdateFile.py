#! /usr/local/bin/python python
#-*- encoding: utf-8 -*-
import sys
reload(sys)
sys.setdefaultencoding('utf-8')
import os
import shutil
import argparse
import hashlib
import re
parser = argparse.ArgumentParser(description='更新包打包软件')
parser.add_argument('-source', help="文件源位置,需要/结尾")
parser.add_argument('-target', help="打包的目标位置,需要/结尾")
parser.add_argument('-project', help="项目路径,需要/结尾")
parser.add_argument("-platform", help = "打包的版本")
parser.add_argument("-apkPath", help = "apk的网络下载路径")
parser.add_argument("-apkFile", help = "apk的本地文件")
parser.add_argument("-notice", help = "公告内容的文件")
parser.add_argument("-appstorePath", help = "appstore的下载路径")
parser.add_argument("-version", default=[] , action = "append" , help = "额外支持的版本列表")
parser.add_argument("-fix", help = "修复的代码文件")
#parser.add_argument("-c", "--copy", action="store_true", default=False, help = "是否需要复制文件")
userArgs = parser.parse_args()
space = " "

def buildFileRecord():
    CheckDirs      = ["res", "src"]
    ExceptFile = []
    connectStr = space+'force={\n'
    for dirs in CheckDirs:
        for parent, dirnames, filenames in os.walk(userArgs.source + dirs):
            for filename in filenames:
                fullname = os.path.join(parent, filename).replace("\\", "/")
                fileSize = os.path.getsize(fullname)
                array = map(fullname.endswith, ExceptFile)
                if True in array:
                    print("忽略文件："+fullname)
                    continue
                fileContent = open(fullname, 'rb')
                md5 = hashlib.md5(fileContent.read()).hexdigest()
                fileContent.close()
                relativePath = re.sub("^" + userArgs.source.replace("." , "\\."), "" , fullname)
                connectStr += space+space+'{file="' + relativePath + '",code="' + md5 + '",size=' + str(fileSize) + '},\n'
    connectStr += space + "},\n"
    return connectStr

def buildAndroidPackPath():
    pass

def getFixFileContext():
    if userArgs.fix and os.path.exists(userArgs.fix):
        fileContent = open(userArgs.fix, 'r')
        txt = fileContent.read()
        fileContent.close()
        if txt and txt.strip() != "":
            return space + "fix = " + txt.strip() + ",\n"
    return ""

def getAndroidNativeVersion():
    manifest = open(userArgs.project + "/runtime-src/proj.android/AndroidManifest.xml", "rb")
    for line in manifest:
        if "android:versionName" in line:
            search = re.search(r'"(.*)"', line, re.M | re.I)
            if search:
                ret = search.group(1)
            else:
                ret = "ERROR"
    manifest.close()
    return ret

def getIosNativeVersion():
    plist = open(userArgs.project +"/runtime-src/proj.ios_mac/ios/Info.plist", "rb")
    nextLine = False
    for line in plist:
        if True == nextLine:
            search = re.search(r'>(.*)<', line, re.M | re.I)
            if search:
                ret = search.group(1)
            else:
                ret = "ERROR"
            break
        if "CFBundleShortVersionString" in line:
            nextLine = True
    plist.close()
    return ret

def StrBool(val):
    if True == val:
        return "true"
    else:
        return 'false'
pass

def getVersionString():
    ver = None
    if userArgs.platform == "ios":
        ver = getIosNativeVersion() 
    elif userArgs.platform == "android":
        ver = getAndroidNativeVersion()
    if ver and not (ver in userArgs.version):
        userArgs.version.append(ver)
    ret = "{"
    for v in userArgs.version:
        ret += "'" + v + "',"
    ret += "}"
    return space + "ver = " + ret + ",\n"

def getNewPackageString():
    ret = ""
    if userArgs.platform == "ios" and userArgs.appstorePath:
        ret += space + 'path = "' + userArgs.appstorePath + '",\n'
    elif userArgs.platform == "android":
        if userArgs.apkPath:
            ret += space + 'path = "' + userArgs.apkPath + '",\n' 
        if userArgs.apkFile and os.path.exists(userArgs.apkFile):
            fileContent = open(userArgs.apkFile, 'rb')
            md5 = hashlib.md5(fileContent.read()).hexdigest()
            fileContent.close()
            fileSize = os.path.getsize(userArgs.apkFile)
            ret += space + 'code = "' + md5 + '",\n' 
            ret += space + 'size = ' + str(fileSize) + ',\n' 
    return ret         

def getNoticeString():
    if userArgs.notice and os.path.exists(userArgs.notice):
        fileContent = open(userArgs.notice)
        text = fileContent.read()
        fileContent.close()
        return space + 'notice = [[' + text + ']],\n'
    else:
        return ""

def buildAllFile():
    isForce = True
    # 1 复制文件到目标文件夹
    fileFolder = userArgs.target + userArgs.platform + "/files"
    if os.path.exists(fileFolder):
        shutil.rmtree(fileFolder)
    shutil.copytree(userArgs.source, fileFolder)
    # 2 建立更新的列表文件
    connectStr = "return {\n"
    connectStr += getFixFileContext()
    connectStr += buildFileRecord()
    connectStr += space + "isForce = " + StrBool(isForce)  + ",\n" 
    connectStr += getVersionString() 
    connectStr += getNewPackageString()
    connectStr += getNoticeString()
    connectStr += "}"
    file = open(userArgs.target + userArgs.platform + "/updatelist.xml" , "w+")
    file.write(connectStr)
    file.close()
    file = open(userArgs.target + userArgs.platform + "/listmd5.xml" , "w+")
    fileContent = open(userArgs.target + userArgs.platform + "/updatelist.xml", 'rb')
    md5 = hashlib.md5(fileContent.read()).hexdigest()
    fileContent.close()
    file.write(md5)
    file.close()


buildAllFile()