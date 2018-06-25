# -*- coding: UTF-8 -*-
import os
import sys
ScriptPath = os.path.split( os.path.realpath( sys.argv[0] ) )[0]

def file_extension(path): 
  return os.path.splitext(path)[1] 

def checkFileIsNeedEncry(fileName):
    ignoreList = [ ".jpg", ".ttf", ".mp3", ".ogg"]
    extName = file_extension(fileName)
    if extName.lower() in ignoreList:
        return False
    return True

encryptArr = []
def initEncryptArr():
    if len(encryptArr) > 0:
        return
    with open(ScriptPath + "\encrypt.key", 'rb') as f:
        cont = f.read(1)
        while len(cont) >0 :
            encryptArr.append(ord(cont[0]))
            cont = f.read(1)

def encryptFile(filePath , targetFile = ""):
    if targetFile == "":
        targetFile = filePath
    initEncryptArr()
    length = len(encryptArr)
    if not checkFileIsNeedEncry(filePath):
        return
    with open(filePath, 'rb') as f:
        fsize = os.path.getsize(filePath)
        readFile = f.read()
    if fsize >= 6 \
        and ord(readFile[fsize - 1]) == encryptArr[(fsize - 0) % length] \
        and ord(readFile[fsize - 2]) == encryptArr[(fsize - 1) % length] \
        and ord(readFile[fsize - 3]) == encryptArr[(fsize - 2) % length] \
        and ord(readFile[fsize - 4]) == encryptArr[(fsize - 3) % length] \
        and ord(readFile[fsize - 5]) == encryptArr[(fsize - 4) % length] \
        and ord(readFile[fsize - 6]) == encryptArr[(fsize - 5) % length]:
        return
    print("xor: %s" % filePath)
    with open(targetFile , 'wb') as tf:
        for i in xrange(fsize):
            tf.write(chr(ord(readFile[i]) ^ encryptArr[fsize % length]))
        tf.write(chr(encryptArr[(fsize + 1) % length]))
        tf.write(chr(encryptArr[(fsize + 2) % length]))
        tf.write(chr(encryptArr[(fsize + 3) % length]))
        tf.write(chr(encryptArr[(fsize + 4) % length]))
        tf.write(chr(encryptArr[(fsize + 5) % length]))
        tf.write(chr(encryptArr[(fsize + 6) % length]))
    

#runPath("D:/work/trunk/client/game/res/ui/common" , "D:/work/trunk/client/game/res/ui/common")
#encryptFile( "D:/work/trunk/client/game/res/local_global.json")
#encryptFile( "D:/work/trunk/client/game/res/ui/LoginView.csb")
#encryptFile("D:/work/trunk/client/game/res/particle/jinbi.plist" , "D:/work/trunk/client/game/res/particle/jinbi.plist2")
