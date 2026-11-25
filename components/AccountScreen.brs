sub init()
    m.who = m.top.findNode("who")
    m.button = m.top.findNode("signout")
    m.button.observeField("buttonSelected", "onSignOut")
    m.top.observeField("focusedChild", "onFocusChange")
    m.task = runApi({ kind: "user" }, "onUser")
end sub

sub onFocusChange()
    if m.top.hasFocus() then m.button.setFocus(true)
end sub

sub onUser(event as object)
    r = event.getData()
    if r.expired
        m.who.text = "Session expired"
    else if r.who <> ""
        m.who.text = "Signed in as " + r.who
    end if
end sub

sub onSignOut()
    m.top.action = { kind: "signout" }
end sub
