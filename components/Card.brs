sub init()
    m.thumb = m.top.findNode("thumb")
    m.badge = m.top.findNode("badge")
    m.dur = m.top.findNode("dur")
    m.prog = m.top.findNode("prog")
    m.title = m.top.findNode("title")
    m.meta = m.top.findNode("meta")
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.thumb.uri = c.hdPosterUrl
    m.title.text = c.title
    m.meta.text = c.meta
    m.dur.text = c.durtext
    m.badge.visible = c.durtext <> ""
    m.prog.width = 404 * c.progress
end sub
