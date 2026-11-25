sub init()
    m.video = m.top.findNode("video")
    m.status = m.top.findNode("status")
    m.upnext = m.top.findNode("upnext")
    m.upnextTitle = m.top.findNode("upnextTitle")
    m.progTimer = m.top.findNode("progTimer")
    m.nextTimer = m.top.findNode("nextTimer")
    m.video.observeField("state", "onState")
    m.progTimer.observeField("fire", "onProgTimer")
    m.nextTimer.observeField("fire", "onNextTimer")
    m.top.observeField("focusedChild", "onFocusChange")
    m.top.observeField("closing", "onClosing")
    m.ep = invalid
    m.dirty = false
    m.finalBody = invalid
    m.nextPath = ""
end sub

sub onFocusChange()
    if m.top.hasFocus() then m.video.setFocus(true)
end sub

sub onPath()
    load(m.top.path, false)
end sub

sub load(path as string, fromStart as boolean)
    m.ep = invalid
    m.upnext.visible = false
    m.status.visible = true
    m.task = runApi({ kind: "episode", path: path, fromstart: fromStart }, "onEpisode")
end sub

sub onEpisode(event as object)
    r = event.getData()
    if m.top.closing then return
    if not r.ok
        m.top.action = { kind: "fail", text: "Could not load episode: " + r.message, relogin: false }
        return
    end if
    if r.url = ""
        m.top.action = { kind: "fail", text: txt(r.why), relogin: r.relogin }
        return
    end if
    m.ep = r.episode

    content = CreateObject("roSGNode", "ContentNode")
    content.url = r.url
    content.streamFormat = "hls"
    content.title = txt(m.ep.title)
    ' Resume, unless the saved position is at the very start or the very end.
    if r.resume > 10 and not (r.duration > 0 and r.resume > r.duration - 20)
        content.playStart = Int(r.resume)
        m.top.action = { kind: "toast", text: "Resuming from " + clock(r.resume) }
    end if
    m.video.content = content
    m.video.control = "play"
    m.video.setFocus(true)
    m.progTimer.control = "start"
end sub

sub onState()
    if m.top.closing then return
    state = m.video.state
    if state = "playing"
        m.status.visible = false
    else if state = "paused"
        report(false)
    else if state = "finished"
        onFinished()
    else if state = "error"
        m.finalBody = progressBody(false)
        m.top.action = { kind: "fail", text: "Playback error: " + toStr(m.video.errorMsg), relogin: false }
    end if
end sub

sub onProgTimer()
    if m.video.state = "playing" then report(false)
end sub

function progressBody(finished as boolean) as dynamic
    if m.ep = invalid or getToken() = "" or m.video.duration <= 0 then return invalid
    position = Int(m.video.position)
    duration = Int(m.video.duration)
    if finished then position = duration
    if not finished and position < 15 then return invalid   ' too early to be a meaningful position
    return { episode_id: m.ep.id, content_url: m.ep.content_url, position_seconds: position, duration_seconds: duration, finished: finished }
end function

sub report(finished as boolean)
    body = progressBody(finished)
    if body = invalid then return
    m.dirty = true
    m.saveTask = runApi({ kind: "progress", body: body }, "")
end sub

function nextEpisode() as dynamic
    list = m.ep.playlist_episodes
    if type(list) <> "roArray" then return invalid
    for i = 0 to list.Count() - 2
        if toStr(list[i].id) = toStr(m.ep.id) then return list[i + 1]
    end for
    return invalid
end function

sub onFinished()
    m.progTimer.control = "stop"
    upcoming = nextEpisode()
    if upcoming = invalid
        ' This screen is about to go away, so let the scene do the final save.
        m.finalBody = progressBody(true)
        m.top.action = { kind: "back" }
        return
    end if
    report(true)
    m.nextPath = toStr(upcoming.path)
    m.upnextTitle.text = txt(upcoming.title)
    m.upnext.visible = true
    m.nextTimer.control = "start"
end sub

sub onNextTimer()
    if m.top.closing then return
    load(m.nextPath, true)
end sub

sub onClosing()
    m.progTimer.control = "stop"
    m.nextTimer.control = "stop"
    ' Cancel any periodic save still in flight so it cannot land after the final one.
    if m.saveTask <> invalid then m.saveTask.control = "stop"
    body = m.finalBody
    state = m.video.state
    if state = "playing" or state = "paused" or state = "buffering" then body = progressBody(false)
    m.video.control = "stop"
    m.top.action = { kind: "closed", dirty: m.dirty, body: body }
end sub
