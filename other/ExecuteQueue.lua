local ExecuteQueue = class("ExecuteQueue")

ExecuteQueue.StepType = {
    Func = "Func",
    View = "View",
}

function ExecuteQueue:ctor()
    self:reset()
end

function ExecuteQueue:start()
    if self._isStart then return end
    self._isStart = true
    if not self._isRunning then 
        self:nextStep()
    end
end

function ExecuteQueue:reset()
    self.pauseNum = 0
    self.stepList = {}
    self._isStart = nil
    self._isRunning = nil
end

function ExecuteQueue:addStep(step)
    if DEBUG == 1 then
        print("执行队列添加步骤:")
        log(step)
    end
    step.priority = step.priority or 0
    local index = #self.stepList
    while index >= 1 do
        if self.stepList[index].priority < step.priority then
            self.stepList[index + 1] = self.stepList[index]
        else
            break
        end
        index = index - 1
    end
    self.stepList[index + 1] = step
    if not self._isRunning then 
        self:nextStep()
    end
end

function ExecuteQueue:pause()
    self.pauseNum = self.pauseNum + 1
end

function ExecuteQueue:continue()
    self.pauseNum = self.pauseNum - 1
    if self.pauseNum <= 0 and not self._isRunning then
        self:nextStep()
    end
end

function ExecuteQueue:exeStep(step)
    self._isRunning = true
    if step.type == ExecuteQueue.StepType.Func then
        xpcall(function()
            step.func(function()
                self._isRunning = false
                self:nextStep()
            end)
        end , function(...)
            __G__TRACKBACK__(...)
            self._isRunning = false
            self:nextStep()
        end)
    elseif step.type == ExecuteQueue.StepType.View then
        xpcall(function()
            local v = step.func()
            local cleanIndex
            cleanIndex = v:addCleanCallBack(function()
                v:removeCleanCallBack(cleanIndex)
                self._isRunning = false
                self:nextStep()
            end)
        end, function(...)
            __G__TRACKBACK__(...)
            self._isRunning = false
            self:nextStep()
        end)
        
    end
end

function ExecuteQueue:nextStep()
    if self._isStart and self.pauseNum <= 0 and not self._isRunning then
        if #self.stepList > 0 then
            self._isRunning = true
            scheduler.performWithDelayGlobal(function ()
                local step = table.remove(self.stepList , 1)
                if step then 
                    self:exeStep(step)
                else
                    self._isRunning = false
                end
	        end, 0)
        end
    end
end

return ExecuteQueue