local audioEngine = {}

audioEngine.bgMusicId = -1
local isPlayingBgMusic = false;
local isPlayingEffect = true;
-- local audioEngine.bgMusicId = -1;
local bgMusicUrl = "";       
local bgMusicVolume = 0.2;             
local SoundEffectVolume = 0.5;
local effectMap = {};
local enterVolume = 0;

-- 进入后台 
audioEngine.enterBackground = function()
    local lastVolBg  = bgMusicVolume
	local lastVolEff = SoundEffectVolume
	print("声音管理,切到后台 " .. lastVolBg)
	audioEngine.setBgMusicVolume(0)
	audioEngine.setSoundEffectVolume(0)
	bgMusicVolume = lastVolBg
	SoundEffectVolume = lastVolEff
end

-- 进入前台
audioEngine.enterForeground = function()
    audioEngine.setBgMusicVolume(bgMusicVolume)
	if isPlayingEffect then
		audioEngine.setSoundEffectVolume(SoundEffectVolume)
	end
end

audioEngine.initData = function (soundOn, musicVolume, soundVolume)
	isPlayingEffect = soundOn;
	bgMusicVolume = musicVolume;
	SoundEffectVolume = soundVolume; 
end

-- 播放背景音乐
audioEngine.playBgMusic = function (path, loop)
	
	if (isPlayingBgMusic and path == bgMusicUrl)then return end
	if (audioEngine.bgMusicId ~= cc.AUDIO_INVAILD_ID)then
		ccexp.AudioEngine:stop(audioEngine.bgMusicId);
	end
	if(loop == nil) then
		loop = true;
	end

	bgMusicUrl = path or bgMusicUrl;
	if bgMusicUrl and bgMusicUrl ~= "" then
		audioEngine.bgMusicId = ccexp.AudioEngine:play2d(path, loop, bgMusicVolume);
		isPlayingBgMusic = true;
	end
end

audioEngine.pauseAll = function()
    ccexp.AudioEngine:pauseAll()
end

audioEngine.resumeAll = function()
    ccexp.AudioEngine:resumeAll()
end

audioEngine.preloadMusic = function(filename)
    ccexp.AudioEngine:preload(filename)
end

-- 暂停背景音乐
audioEngine.pauseBgMusic = function ()
	if (not isPlayingBgMusic or audioEngine.bgMusicId == cc.AUDIO_INVAILD_ID)then return end
    ccexp.AudioEngine:pause(audioEngine.bgMusicId)
end

-- 继续背景音乐
audioEngine.resumeBgMusic = function()
    if (not isPlayingBgMusic or audioEngine.bgMusicId == cc.AUDIO_INVAILD_ID)then return end
    ccexp.AudioEngine:resume(audioEngine.bgMusicId)
end

-- 停止播放音乐
audioEngine.stopBgMusic = function( )
	if (not isPlayingBgMusic or audioEngine.bgMusicId == cc.AUDIO_INVAILD_ID)then return end
	isPlayingBgMusic = false;
	ccexp.AudioEngine:stop(audioEngine.bgMusicId)
	audioEngine.bgMusicId = cc.AUDIO_INVAILD_ID
end

-- 播放音效
audioEngine.playEffect = function (path, loop , volumePercent)
	if (isPlayingEffect == false or SoundEffectVolume <= 0)then return end;
    volumePercent = volumePercent or 1
	if(loop == nil)then loop = false end;
	return ccexp.AudioEngine:play2d(path, loop, SoundEffectVolume * volumePercent)
end

-- 停止一个音效
audioEngine.stopEffect = function(id)
    ccexp.AudioEngine:stop(id)
end

-- 暂停一个音效
audioEngine.pauseEffect = function(id)
    ccexp.AudioEngine:pause(id)
end

-- 恢复一个音效
audioEngine.resumeEffect = function(id)
    ccexp.AudioEngine:resume(id)
end

-- 设置音效声音
audioEngine.setEffectVolume = function(id , volume)
    ccexp.AudioEngine:setVolume(audioEngine.bgMusicId, bgMusicVolume);
end

-- 设置背景音乐音量
audioEngine.setBgMusicVolume = function(v)
	bgMusicVolume = v;
	if (audioEngine.bgMusicId == nil or audioEngine.bgMusicId == cc.AUDIO_INVAILD_ID)then return end;
	ccexp.AudioEngine:setVolume(audioEngine.bgMusicId, bgMusicVolume);
end

audioEngine.getBgMusicVolume = function()
    return bgMusicVolume
end

-- 设置音效音量
audioEngine.setSoundEffectVolume = function(v)
	SoundEffectVolume = v;
	if (v > 0)then
		isPlayingEffect = true;
	end
end

audioEngine.getSoundEffectVolume = function()
    return SoundEffectVolume
end

audioEngine.setPlaySoundStatus = function(isplay)
	isPlayingEffect = isplay;
end

-- 是否正在播放背景音乐
audioEngine.getIsPlayBgMusic = function()
	return isPlayingBgMusic;
end

return audioEngine;