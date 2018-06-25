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

def removeFile(targetPath):
    if os.path.exists(targetPath):
        print("delete file----> " + targetPath)
        if os.path.isdir(targetPath):
            shutil.rmtree(targetPath)
        elif os.path.isfile(targetPath):
            os.remove(targetPath)
       

def solveFile(fileList , fromPath, toPath = ""):
    files = {}
    f = open(fileList, "r")  
    while True:
        line = f.readline()
        if line:
            files[line[8:-1]] = line[0]
            pass 
        else:
            break
    f.close()
    os.remove(fileList)
    for filePath, mode in files.items():
        targetPath = filePath.replace(fromPath, toPath)
        if mode != "D":
            if(os.path.isfile(filePath)): 
                shutil.copyfile(filePath, targetPath)
                if config["compressImage"]:
                    compressImage.compress_image(targetPath)
                if config["encry"]:
                    if os.path.splitext(targetPath)[1] == ".lua":
                        xxtea.encryptFile(targetPath)
                    encryptFile.encryptFile(targetPath)  
        else:
            removeFile(targetPath)

def runPath(fromPath , toPath = ""):
    if fromPath != toPath and not os.path.exists(toPath):
        os.makedirs(toPath)
    cmd = "svn up"
    os.system(cmd)
    listFileName = "fileList.list"
    svn_version1 = raw_input("svn Resources Version1: ")
    svn_version2 = raw_input("svn Resources Version2: ")
    if svn_version2 == "":
    	svn_version2 = "HEAD"
    cmd = "svn diff -r " + svn_version1 + ":"+ svn_version2 +" --summarize " + fromPath + " >"+ listFileName 
    os.system(cmd)
    solveFile(listFileName, fromPath, toPath)

runPath(sys.argv[1] , sys.argv[2])