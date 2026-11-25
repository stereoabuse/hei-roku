' Shared helpers, included by main and by every component.

function isStr(v as dynamic) as boolean
    t = LCase(type(v))
    return t = "string" or t = "rostring"
end function

function toStr(v as dynamic) as string
    if v = invalid then return ""
    t = LCase(type(v))
    if t = "string" or t = "rostring" then return v
    if t = "boolean" or t = "roboolean"
        if v then return "true"
        return "false"
    end if
    if t = "integer" or t = "roint" or t = "rointeger" or t = "longinteger" or t = "rolonginteger" or t = "float" or t = "rofloat" or t = "double" or t = "rodouble"
        return Str(v).Trim()
    end if
    return ""
end function

function toNum(v as dynamic) as float
    if v = invalid then return 0
    t = LCase(type(v))
    if t = "string" or t = "rostring" then return Val(v)
    if t = "boolean" or t = "roboolean"
        if v then return 1
        return 0
    end if
    if t = "integer" or t = "roint" or t = "rointeger" or t = "longinteger" or t = "rolonginteger" or t = "float" or t = "rofloat" or t = "double" or t = "rodouble"
        return v
    end if
    return 0
end function

' The API gives durations as "418", "14:55" or "1:02:03".
function secs(d as dynamic) as float
    if not isStr(d) then return toNum(d)
    total = 0
    for each part in d.Split(":")
        total = total * 60 + Val(part)
    end for
    return total
end function

function clock(s as dynamic) as string
    n = Int(toNum(s))
    if n < 0 then n = 0
    h = n \ 3600
    mi = (n mod 3600) \ 60
    x = n mod 60
    xs = x.ToStr()
    if x < 10 then xs = "0" + xs
    if h = 0 then return mi.ToStr() + ":" + xs
    ms = mi.ToStr()
    if mi < 10 then ms = "0" + ms
    return h.ToStr() + ":" + ms + ":" + xs
end function

' Decode the HTML entities the API leaves in titles.
function txt(s as dynamic) as string
    out = toStr(s)
    if Instr(1, out, "&") = 0 then return out
    re = CreateObject("roRegex", "&#(x?)([0-9a-fA-F]+);", "i")
    for i = 1 to 50
        found = re.Match(out)
        if found.Count() < 3 then exit for
        if found[1] <> "" then code = Val(found[2], 16) else code = Val(found[2], 10)
        ch = ""
        if code > 0 and code <> 92 then ch = Chr(code)
        if code = 38 then ch = "&amp;"
        out = re.Replace(out, ch)
    end for
    out = out.Replace("&nbsp;", " ").Replace("&quot;", Chr(34)).Replace("&apos;", "'")
    out = out.Replace("&lt;", "<").Replace("&gt;", ">").Replace("&amp;", "&")
    return out
end function

function cleanPath(p as dynamic) as string
    re = CreateObject("roRegex", "^/+|/+$", "")
    return re.ReplaceAll(toStr(p), "")
end function

function getToken() as string
    sec = CreateObject("roRegistrySection", "hei")
    if sec.Exists("token") then return sec.Read("token")
    return ""
end function

sub setToken(token as string)
    sec = CreateObject("roRegistrySection", "hei")
    if token = "" then sec.Delete("token") else sec.Write("token", token)
    sec.Flush()
end sub

' The activation result shape is not documented; look for a token-ish field.
function findToken(o as dynamic, depth = 0 as integer) as string
    if depth > 4 then return ""
    if type(o) = "roArray"
        for each item in o
            t = findToken(item, depth + 1)
            if t <> "" then return t
        end for
        return ""
    end if
    if type(o) <> "roAssociativeArray" then return ""
    for each k in ["token", "jwt", "access_token", "accessToken", "auth_token"]
        v = o[k]
        if isStr(v) and Len(v) > 20 then return v
    end for
    for each k in o
        t = findToken(o[k], depth + 1)
        if t <> "" then return t
    end for
    return ""
end function

' playback_url may be a string or a wrapper object.
function findStream(o as dynamic, depth = 0 as integer) as string
    if isStr(o)
        if LCase(Left(o, 7)) = "http://" or LCase(Left(o, 8)) = "https://" then return o
        return ""
    end if
    if type(o) <> "roAssociativeArray" or depth > 4 then return ""
    for each k in ["url", "playback_url", "hls", "src", "data"]
        t = findStream(o[k], depth + 1)
        if t <> "" then return t
    end for
    return ""
end function

' Start a one-shot ApiTask. The caller must keep the returned node referenced until it responds.
function runApi(req as object, callback as string) as object
    task = CreateObject("roSGNode", "ApiTask")
    task.request = req
    if callback <> "" then task.observeField("response", callback)
    task.control = "RUN"
    return task
end function
