# -*- coding: UTF-8 -*-
import encryptFile
import compressImage
import shutil
import os
import sys

import fileRecord
import xxtea
config = {
    "encry" : True,
    "compressImage" : True,
    "record" : True,
}

def checkNeedRemoveFile(fromPath , toPath):
    if fromPath == toPath:
        return
    files = os.listdir(toPath)
    for f in files:
        orgPath = fromPath + '/' + f
        targetPath = toPath + '/' + f
        if(os.path.isdir(targetPath)): 
            if not os.path.exists(orgPath):
                shutil.rmtree(targetPath)
            else:
                checkNeedRemoveFile(orgPath , targetPath )
        elif(os.path.isfile(targetPath)):
            if not os.path.exists(orgPath):
                os.remove(targetPath)

def solveFile(fromPath , toPath = ""):
    files = os.listdir(fromPath)
    if fromPath != toPath and not os.path.exists(toPath):
        os.makedirs(toPath)
    for f in files:
        orgPath = fromPath + '/' + f
        targetPath = toPath + '/' + f
        if(os.path.isdir(orgPath)):  
            solveFile(orgPath , targetPath )
        elif(os.path.isfile(orgPath)):  
            if not config["record"] \
                or not fileRecord.checkFile(orgPath , targetPath) \
                or not os.path.exists(targetPath):
                if targetPath != orgPath :
                    shutil.copyfile(orgPath,targetPath)
                if config["compressImage"]:
                    compressImage.compress_image(targetPath)
                if config["encry"]:
                    if os.path.splitext(targetPath)[1] == ".lua":
                        xxtea.encryptFile(targetPath)
                    encryptFile.encryptFile(targetPath)
                if config["record"]:
                    fileRecord.saveRecord(orgPath , targetPath)

def runPath(fromPath , toPath = ""):
    if toPath == "" :
        toPath = fromPath
    solveFile(fromPath , toPath)
    checkNeedRemoveFile(fromPath , toPath)
    
print(sys.argv)
if len(sys.argv) >= 3:
    runPath(sys.argv[1] , sys.argv[2])
elif len(sys.argv) >= 2:
    runPath(sys.argv[1])
else:
    #runPath("D:/clean_client/frameworks/runtime-src/proj.android/encrypt_assert")
    pass