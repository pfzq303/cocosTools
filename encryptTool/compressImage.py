# -*- coding: UTF-8 -*-
import os
import subprocess
import sys
ScriptPath = os.path.split( os.path.realpath( sys.argv[0] ) )[0]

def initIgnoreFileList():
    ret = []
    if os.path.exists('./IgnoreIMG.list'):
        with open("./IgnoreIMG.list", 'rt') as f: 
            for line in  f.readlines():
                line.replace("\n" , "")
                ret.append(line)
    return ret
IgnoreFileList = initIgnoreFileList()
print("IgnoreFileList:")
print(IgnoreFileList)

def file_extension(path): 
    return os.path.splitext(path)[1] 

def checkNeedCompress(path):
    compressList = [".png"]
    extName = file_extension(path)
    if extName.lower() in compressList:
        for s in IgnoreFileList:
            if path.replace("\\" , "/").endswith(s) :
                return False
        return True
    return False

def compress_image(path , targetPath = ""):
    #extName = file_extension(path)
    if not checkNeedCompress(path):
        return
    path = path.replace("/" , "//")
    targetPath = targetPath.replace("/" , "//")
    if targetPath == "" :
        targetPath = path
    speed = 3

    cmd = "%s\pngquant\pngquant --force 256 --speed %d %s -o %s" % (ScriptPath, speed , path, targetPath )
    if subprocess.Popen(cmd, shell=True).wait() == 0:
        print("compress image:" + path)

#compress_image("D:/clean_client/game/res/ui/yanhuo00.png")