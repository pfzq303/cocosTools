# -*- coding:UTF-8 -*-
import pickle
import os
import time
import fileMd5
recordFile = "./fileRecord.list"

def readRecord():
    #如果存在备份文件，说明上次关闭时文件出现了错误
    if os.path.exists(recordFile + ".bak"):
        with open(recordFile + ".bak",'r') as f:
            data=pickle.load(f)
        return data
    elif os.path.exists(recordFile):
        with open(recordFile,'r') as f:
            data=pickle.load(f)
        return data
    return {}

local_record = readRecord()

def saveRecord(orgPath , targetPath):
    target_md5 = fileMd5.getFileMd5(targetPath)
    history = local_record.get(orgPath)
    history["target_md5"] = target_md5
    if os.path.exists(recordFile):
        if os.path.exists(recordFile + ".bak"):
            os.remove(recordFile + ".bak")
        #备份一下，以防中断时导致了文件的错误
        os.rename(recordFile , recordFile + ".bak")
    with open(recordFile,'w') as f:
        pickle.dump(local_record , f)
    if os.path.exists(recordFile + ".bak"):
        os.remove(recordFile + ".bak")

def checkFile(orgPath , targetPath):
    org_md5 = fileMd5.getFileMd5(orgPath)
    history = local_record.get(orgPath)
    if not history or history["org_md5"] != org_md5:
        if not history:
            print("createFileRecord:%s" % orgPath)
        local_record[orgPath] = { "org_md5" : org_md5 , "target_md5" : "" }
        return False
    else:
        target_md5 = fileMd5.getFileMd5(targetPath)
        if history["target_md5"] != target_md5:
            return False
    return True

#checkFile( "D:/work/trunk/client/game/res/ui/LoginView.csb")
#saveRecord(local_record)