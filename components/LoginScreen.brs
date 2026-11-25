sub init()
    m.panel = m.top.findNode("panel")
    m.qr = m.top.findNode("qr")
    m.how = m.top.findNode("how")
    m.codeLabel = m.top.findNode("code")
    m.status = m.top.findNode("status")
    m.pollTimer = m.top.findNode("pollTimer")
    m.pollTimer.observeField("fire", "onPollTimer")
    m.top.observeField("closing", "onClosing")
    m.code = ""
    m.polling = false
    m.clock = CreateObject("roTimespan")
    m.task = runApi({ kind: "generate" }, "onCode")
end sub

sub onClosing()
    m.pollTimer.control = "stop"
end sub

sub onCode(event as object)
    r = event.getData()
    if m.top.closing then return
    if not r.ok or toStr(r.code) = ""
        m.status.text = "Could not get a sign-in code (" + r.message + "). Press BACK and try again."
        return
    end if
    m.code = r.code
    site = r.activate
    if site = "" then site = "https://www.heinetwork.tv/activate"
    site = CreateObject("roRegex", "^https?://(www\.)?", "i").Replace(site, "")
    site = site.Split("?")[0]
    m.qr.uri = r.qrfile
    m.how.text = "Scan the code with your phone, or go to " + site + " and enter:"
    m.codeLabel.text = m.code
    m.status.text = "Waiting for you to confirm..."
    m.panel.visible = true
    m.clock.Mark()
    m.pollTimer.control = "start"
end sub

sub onPollTimer()
    if m.polling then return
    if m.clock.TotalSeconds() > 19 * 60
        finish("Code expired. Press BACK and try again.")
        return
    end if
    m.polling = true
    m.task = runApi({ kind: "poll", code: m.code }, "onPoll")
end sub

sub onPoll(event as object)
    r = event.getData()
    m.polling = false
    if m.top.closing or r.status = "pending" or r.transient then return
    ' Shape log (never the token itself) so an unexpected response can be diagnosed.
    print "[hei] activation status: "; r.status; " token: "; r.token <> ""
    if r.token <> ""
        setToken(r.token)
        m.pollTimer.control = "stop"
        m.top.action = { kind: "signedin" }
        return
    end if
    reason = r.status
    if reason = "" then reason = "unknown"
    finish("Activation did not complete (" + reason + "). Press BACK and try again.")
end sub

sub finish(message as string)
    m.pollTimer.control = "stop"
    m.status.text = message
end sub
