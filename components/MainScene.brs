sub init()
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x0B0B0DFF"
    m.stack = m.top.findNode("stack")
    m.toast = m.top.findNode("toast")
    m.toastLabel = m.top.findNode("toastLabel")
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "onToastDone")
    m.homeStale = false
    m.saveTasks = []
    reset()
end sub

sub push(component as string, fields as object)
    count = m.stack.getChildCount()
    if count > 0 then m.stack.getChild(count - 1).visible = false
    screen = CreateObject("roSGNode", component)
    screen.observeField("action", "onAction")
    m.stack.appendChild(screen)
    screen.setFields(fields)
    screen.setFocus(true)
end sub

function pop() as boolean
    count = m.stack.getChildCount()
    if count <= 1 then return false
    screen = m.stack.getChild(count - 1)
    screen.closing = true
    m.stack.removeChild(screen)
    prev = m.stack.getChild(count - 2)
    prev.visible = true
    prev.setFocus(true)
    refreshHome()
    return true
end function

sub reset()
    while m.stack.getChildCount() > 0
        screen = m.stack.getChild(m.stack.getChildCount() - 1)
        screen.closing = true
        m.stack.removeChild(screen)
    end while
    m.homeStale = false
    push("BrowseScreen", { source: "home" })
end sub

' Reload the home screen once it is visible again, so "Continue watching" is current.
sub refreshHome()
    if m.homeStale and m.stack.getChildCount() = 1 then reset()
end sub

sub openEpisode(path as string)
    if path = "" then return
    if getToken() = ""
        toast("Sign in to watch", 4)
        push("LoginScreen", {})
    else
        push("PlayerScreen", { path: path })
    end if
end sub

sub onAction(event as object)
    a = event.getData()
    if a = invalid then return
    kind = a.kind
    if kind = "category"
        push("BrowseScreen", { source: a.path })
    else if kind = "episode"
        openEpisode(a.path)
    else if kind = "redirect"
        pop()
        openEpisode(a.path)
    else if kind = "login"
        push("LoginScreen", {})
    else if kind = "account"
        push("AccountScreen", {})
    else if kind = "signedin"
        toast("Signed in", 4)
        reset()
    else if kind = "signout"
        setToken("")
        toast("Signed out", 4)
        reset()
    else if kind = "toast"
        toast(a.text, 4)
    else if kind = "back"
        pop()
    else if kind = "fail"
        pop()
        toast(a.text, 6)
        if a.relogin = true
            setToken("")
            push("LoginScreen", {})
        end if
    else if kind = "closed"
        ' A player is going away. Save its last position, then refresh the home rows.
        if a.body <> invalid
            m.saveTasks.push(runApi({ kind: "progress", body: a.body }, "onSaved"))
        else if a.dirty = true
            m.homeStale = true
            refreshHome()
        end if
    end if
end sub

sub onSaved(event as object)
    finished = event.getRoSGNode()
    for i = 0 to m.saveTasks.Count() - 1
        if m.saveTasks[i].isSameNode(finished)
            m.saveTasks.Delete(i)
            exit for
        end if
    end for
    m.homeStale = true
    refreshHome()
end sub

sub toast(text as string, seconds as integer)
    m.toastLabel.text = text
    m.toast.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.duration = seconds
    m.toastTimer.control = "start"
end sub

sub onToastDone()
    m.toast.visible = false
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back" then return pop()
    return false
end function
