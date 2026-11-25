' All network access. Uses the site's own app API (hei-app/v1): public catalogue,
' activation-code sign-in, and playback URLs that are only returned for a signed-in member.

sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    req = m.top.request
    kind = req.kind
    res = { kind: kind, ok: true, message: "" }

    if kind = "home"
        r = http("home")
        if (r.status = 401 or r.status = 403) and getToken() <> ""
            ' The stored token was rejected: drop it so the user can sign in again.
            setToken("")
            r = http("home")
        end if
        copyStatus(res, r)
        if r.ok
            res.home = r.data
            res.nav = []
            n = http("navigation")
            if n.ok and type(n.data) = "roAssociativeArray" and type(n.data.main) = "roArray" then res.nav = n.data.main
            res.progress = savedProgress()
        end if

    else if kind = "category"
        r = http(cleanPath(req.path))
        copyStatus(res, r)
        if r.ok
            res.category = r.data
            res.progress = savedProgress()
        end if

    else if kind = "episode"
        r = http(cleanPath(req.path))
        copyStatus(res, r)
        if r.ok and type(r.data) = "roAssociativeArray"
            ep = r.data
            res.episode = ep
            res.url = findStream(ep.playback_url)
            res.why = "This episode is not available on your account."
            res.relogin = false
            pu = ep.playback_url
            if type(pu) = "roAssociativeArray"
                if type(pu.data) = "roAssociativeArray" and isStr(pu.data.error)
                    res.why = pu.data.error
                else if isStr(pu.error)
                    res.why = pu.error
                end if
                ' A rejected session comes back as 403 with loggedIn false, not 401.
                res.relogin = toNum(pu.status) = 401 or toStr(ep["loggedIn"]) = "false"
            end if
            res.resume = 0
            res.duration = 0
            if req.fromstart <> true
                saved = savedProgress()[toStr(ep.id)]
                if saved <> invalid
                    res.resume = saved.position
                    res.duration = saved.duration
                end if
            end if
        else if r.ok
            res.ok = false
            res.message = "Unexpected response"
        end if

    else if kind = "generate"
        r = http("activation/generate-code", "hei-app/v1", invalid, true)
        copyStatus(res, r)
        if r.ok and type(r.data) = "roAssociativeArray"
            res.code = toStr(r.data.code)
            res.activate = toStr(r.data.activate)
            res.qrfile = saveQr(toStr(r.data.qr_base64), res.code)
        end if

    else if kind = "poll"
        r = http("activation/poll?code=" + toStr(req.code).EncodeUriComponent(), "hei-app/v1", invalid, true)
        res.status = ""
        if type(r.data) = "roAssociativeArray"
            res.status = toStr(r.data.status)
            if res.status = "" then res.status = toStr(r.data.error)
        end if
        if res.status = "" and not r.ok then res.status = "error: " + r.message
        res.token = findToken(r.data)
        ' No HTTP answer, or a server error: worth polling again rather than giving up.
        res.transient = r.status <= 0 or r.status >= 500

    else if kind = "user"
        r = http("user_data")
        copyStatus(res, r)
        res.who = ""
        res.expired = r.status = 401 or r.status = 403
        u = r.data
        if r.ok and type(u) = "roAssociativeArray"
            for each k in ["display_name", "name", "email"]
                if res.who = "" then res.who = toStr(u[k])
            end for
            if res.who = "" and type(u.user) = "roAssociativeArray"
                res.who = toStr(u.user.display_name)
                if res.who = "" then res.who = toStr(u.user.email)
            end if
        end if

    else if kind = "progress"
        r = http("progress", "video-progress/v1", req.body)
        copyStatus(res, r)
        if not r.ok then print "[hei] progress not saved: "; r.message
    end if

    m.top.response = res
end sub

sub copyStatus(res as object, r as object)
    res.ok = r.ok
    res.message = r.message
end sub

function http(path as string, ns = "hei-app/v1" as string, body = invalid as dynamic, anon = false as boolean) as object
    result = { ok: false, status: 0, data: invalid, message: "Network error" }
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.RetainBodyOnError(true)
    xfer.SetUrl("https://www.heinetwork.tv/wp-json/" + ns + "/" + path)
    token = getToken()
    if token <> "" and not anon then xfer.AddHeader("Authorization", "Bearer " + token)
    if body <> invalid
        xfer.AddHeader("Content-Type", "application/json")
        started = xfer.AsyncPostFromString(FormatJson(body))
    else
        started = xfer.AsyncGetToString()
    end if
    if not started then return result

    msg = wait(30000, port)
    if type(msg) <> "roUrlEvent"
        xfer.AsyncCancel()
        result.message = "Request timed out"
        return result
    end if
    result.status = msg.GetResponseCode()
    text = msg.GetString()
    if text <> "" then result.data = ParseJson(text)
    result.ok = result.status >= 200 and result.status < 300
    if result.ok
        result.message = ""
    else if result.status < 0
        result.message = msg.GetFailureReason()
    else
        result.message = "HTTP " + result.status.ToStr()
        if type(result.data) = "roAssociativeArray"
            if isStr(result.data.message)
                result.message = txt(result.data.message)
            else if isStr(result.data.error)
                result.message = txt(result.data.error)
            end if
        end if
    end if
    return result
end function

' Episode responses carry no resume position, so positions always come from video-progress/v1.
' Returns {episodeId: {position, duration}} for unfinished episodes.
function savedProgress() as object
    saved = {}
    if getToken() = "" then return saved
    r = http("resume", "video-progress/v1")
    if not r.ok or type(r.data) <> "roArray" then return saved
    for each item in r.data
        if type(item) = "roAssociativeArray" and toNum(item.finished) = 0
            saved[toStr(item.episode_id)] = { position: toNum(item.position_seconds), duration: toNum(item.duration_seconds) }
        end if
    end for
    return saved
end function

' Posters cannot load data: URIs, so the QR code is written to tmp:/ first.
function saveQr(dataUri as string, code as string) as string
    comma = Instr(1, dataUri, ",")
    if comma = 0 then return ""
    bytes = CreateObject("roByteArray")
    bytes.FromBase64String(Mid(dataUri, comma + 1))
    file = "tmp:/qr_" + code + ".png"
    if not bytes.WriteFile(file) then return ""
    return file
end function
