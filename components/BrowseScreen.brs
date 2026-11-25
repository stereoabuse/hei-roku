sub init()
    m.nav = m.top.findNode("nav")
    m.eyebrow = m.top.findNode("eyebrow")
    m.heading = m.top.findNode("heading")
    m.rows = m.top.findNode("rows")
    m.status = m.top.findNode("status")
    m.tabs = []
    m.tabActions = []
    m.tabIndex = 0
    m.navFocused = false
    m.rows.observeField("rowItemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onSource()
    if m.top.source = "home"
        m.task = runApi({ kind: "home" }, "onHome")
    else
        m.task = runApi({ kind: "category", path: m.top.source }, "onCategory")
    end if
end sub

sub onFocusChange()
    if m.top.hasFocus() and not m.navFocused then m.rows.setFocus(true)
end sub

sub showError(message as string)
    m.status.text = "Something went wrong" + Chr(10) + message + Chr(10) + "Press BACK"
    m.status.visible = true
end sub

sub onHome(event as object)
    r = event.getData()
    if m.top.closing then return
    if not r.ok or type(r.home) <> "roAssociativeArray"
        showError(r.message)
        return
    end if
    home = r.home
    prog = r.progress
    buildNav(r.nav)

    rows = []
    h = home.hero
    if type(h) = "roAssociativeArray" and type(h.content) = "roAssociativeArray"
        hero = makeCard("episode", h.content.path, h.content.title, h.image, h.content.eyebrow, "", 0.0)
        rows.push(makeRow("Featured", [hero]))
    end if
    if type(home.resume_episodes) = "roArray" and home.resume_episodes.Count() > 0
        rows.push(makeRow("Continue watching", episodeCards(home.resume_episodes, prog)))
    end if
    if type(home.featured_collections) = "roArray"
        for each fc in home.featured_collections
            if type(fc.episodes) = "roArray" and fc.episodes.Count() > 0
                title = txt(fc.title)
                if toStr(fc.subtitle) <> "" then title = title + "  |  " + txt(fc.subtitle)
                rows.push(makeRow(title, episodeCards(fc.episodes, prog)))
            end if
        end for
    end if
    if type(home.home_collections) = "roArray" and home.home_collections.Count() > 0
        cards = []
        for each c in home.home_collections
            cards.push(makeCard("category", c.path, c.title, c.image, "", "", 0.0))
        end for
        rows.push(makeRow("Browse", cards))
    end if
    showRows(rows)
end sub

sub onCategory(event as object)
    r = event.getData()
    if m.top.closing then return
    c = r.category
    if not r.ok or type(c) <> "roAssociativeArray"
        showError(r.message)
        return
    end if
    if toStr(c.type) = "episode"
        m.top.action = { kind: "redirect", path: m.top.source }
        return
    end if
    if type(c.parent) = "roAssociativeArray" then m.eyebrow.text = UCase(txt(c.parent.name))
    m.heading.text = txt(c.name)

    rows = []
    hasCategories = type(c.categories) = "roArray" and c.categories.Count() > 0
    if hasCategories
        cards = []
        for each sub_ in c.categories
            meta = ""
            if toNum(sub_.episode_count) > 0 then meta = toStr(sub_.episode_count) + " episodes"
            name = sub_.name
            if name = invalid then name = sub_.title
            image = sub_.image_url
            if image = invalid then image = sub_.image
            cards.push(makeCard("category", sub_.path, name, image, meta, "", 0.0))
        end for
        addGrid(rows, "", cards)
    end if
    if type(c.episodes) = "roArray" and c.episodes.Count() > 0
        title = ""
        if hasCategories then title = "Episodes"
        addGrid(rows, title, episodeCards(c.episodes, r.progress))
    end if
    if rows.Count() = 0
        m.status.text = "Nothing here yet."
        return
    end if
    showRows(rows)
end sub

sub showRows(rows as object)
    content = CreateObject("roSGNode", "ContentNode")
    content.appendChildren(rows)
    m.rows.content = content
    m.status.visible = false
end sub

' Four cards fit across the screen, so a grid is just rows of four.
sub addGrid(rows as object, title as string, cards as object)
    chunk = []
    for each card in cards
        chunk.push(card)
        if chunk.Count() = 4
            rows.push(makeRow(title, chunk))
            title = ""
            chunk = []
        end if
    end for
    if chunk.Count() > 0 then rows.push(makeRow(title, chunk))
end sub

function makeRow(title as string, cards as object) as object
    node = CreateObject("roSGNode", "ContentNode")
    node.title = title
    node.appendChildren(cards)
    return node
end function

function makeCard(kind as string, path as dynamic, title as dynamic, image as dynamic, meta as dynamic, durText as string, progress as float) as object
    node = CreateObject("roSGNode", "ContentNode")
    node.addFields({ kind: kind, path: toStr(path), meta: txt(meta), durtext: durText, progress: progress })
    node.title = txt(title)
    node.hdPosterUrl = toStr(image)
    return node
end function

function episodeCards(episodes as object, prog as dynamic) as object
    cards = []
    for each ep in episodes
        total = secs(ep.duration)
        position = 0
        saved = invalid
        if type(prog) = "roAssociativeArray" then saved = prog[toStr(ep.id)]
        if saved <> invalid
            position = saved.position
            if saved.duration > 0 then total = saved.duration
        end if
        durText = ""
        if total > 0 then durText = clock(total)
        fraction = 0.0
        if position > 0 and total > 0 then fraction = position / total
        if fraction > 1 then fraction = 1.0
        image = ep.image_url
        if image = invalid then image = ep.image
        cards.push(makeCard("episode", ep.path, ep.title, image, ep.air_date, durText, fraction))
    end for
    return cards
end function

sub onSelected()
    sel = m.rows.rowItemSelected
    item = m.rows.content.getChild(sel[0]).getChild(sel[1])
    if item <> invalid then m.top.action = { kind: item.kind, path: item.path }
end sub

' ---- top navigation (home only) ----

sub buildNav(navItems as dynamic)
    m.nav.removeChildrenIndex(m.nav.getChildCount(), 0)
    m.tabs = []
    m.tabActions = []
    brand = m.nav.createChild("Label")
    brand.font = "font:SmallBoldSystemFont"
    brand.color = "0xF5C518FF"
    brand.text = "HEI NETWORK"
    note = m.nav.createChild("Label")
    note.font = "font:SmallestSystemFont"
    note.color = "0x9A978FFF"
    note.text = "UNOFFICIAL"
    if type(navItems) = "roArray"
        for each n in navItems
            addTab(txt(n.label), { kind: "category", path: toStr(n.path) })
        end for
    end if
    if getToken() <> ""
        addTab("Account", { kind: "account" })
    else
        addTab("Sign in", { kind: "login" })
    end if
    m.tabIndex = 0
    paintTabs()
end sub

sub addTab(text as string, action as object)
    group = m.nav.createChild("Group")
    label = group.createChild("Label")
    label.font = "font:SmallSystemFont"
    label.text = text
    bar = group.createChild("Rectangle")
    bar.color = "0xF5C518FF"
    bar.height = 4
    bar.translation = [0, 48]
    m.tabs.push({ label: label, bar: bar })
    m.tabActions.push(action)
end sub

sub paintTabs()
    for i = 0 to m.tabs.Count() - 1
        focused = m.navFocused and i = m.tabIndex
        ' Measured here, not at creation, so the label has been laid out.
        m.tabs[i].bar.width = m.tabs[i].label.boundingRect().width
        m.tabs[i].bar.visible = focused
        if focused then m.tabs[i].label.color = "0xFFFFFFFF" else m.tabs[i].label.color = "0xA8A59DFF"
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.navFocused
        if key = "left"
            if m.tabIndex > 0 then m.tabIndex = m.tabIndex - 1
        else if key = "right"
            if m.tabIndex < m.tabs.Count() - 1 then m.tabIndex = m.tabIndex + 1
        else if key = "OK"
            m.top.action = m.tabActions[m.tabIndex]
        else if key = "down"
            m.navFocused = false
            m.rows.setFocus(true)
        else
            return false
        end if
        paintTabs()
        return true
    end if
    if key = "up" and m.tabs.Count() > 0
        m.navFocused = true
        paintTabs()
        m.top.setFocus(true)
        return true
    end if
    return false
end function
