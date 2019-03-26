sub init()
  m.top.functionName = "monitorVideo"
  m.port = CreateObject("roMessagePort")
  m.LivePass = invalid
  m.cSession = invalid
  m.DEBUG = false
  m.video = invalid
end sub

sub monitorVideo()
  if m.top.config.debuggingEnabled = true then m.DEBUG = true
  apiKey = m.top.customerKey
  if m.top.config.gatewayUrl <> invalid
    cfg = {}
    cfg.gatewayUrl = m.top.config.gatewayUrl
    m.LivePass = ConvivaLivePassInitWithSettings(apiKey, cfg)
  else
    m.LivePass = ConvivaLivePassInitWithSettings(apiKey)
  end if

  createConvivaSession()

  while true
    msg = ConvivaWait(0, m.port, invalid)
    if type(msg) = "roSGNodeEvent"
      data = msg.getData()
      field = msg.getField()
      if m.DEBUG then print chr(10) + "New Event caught" + chr(10) + "Field: "; field + chr(10) +  "Data: "; data
      if field = "seek"
        m.LivePass.setPlayerSeekStart(m.cSession, -1)
      else if (field = "state") and (data = "finished")
        livePass.cleanupSession(m.cSession)
      else if (field = "state") and (data = "error")
        livePass.reportError(m.cSession, "Error", m.livePass.StreamerError.SEVERITY_FATAL)
      end if
    end if
  end while
end sub

sub createConvivaSession()
  m.video = m.top.player.findNode("MainVideo")
  contentInfo = fetchContentInfo()
  m.cSession = m.LivePass.createSession(true, contentInfo, 1.0, m.video)
  setFieldObservers()
end sub

function fetchContentInfo()
  contentInfo = ConvivaContentInfo()
  contentInfo.streamUrl = m.video.content.url
  contentInfo.assetName = m.video.content.title
  contentInfo.isLive = m.video.content.live
  contentInfo.playerName = "BitmovinPlayer"
  contentInfo.viewerid = "1234" ' TODO: replace with a proper id or a generated guid
  contentInfo.duration = m.video.duration
  return contentInfo
end function

sub setFieldObservers()
  m.top.player.observeField("seek", m.port)

  m.video.observeField("downloadedSegment", m.port)
  m.video.observeField("duration", m.port)
  m.video.observeField("errorCode", m.port)
  m.video.observeField("errorMsg", m.port)
  m.video.observeField("position", m.port)
  m.video.observeField("state", m.port)
  m.video.observeField("streamInfo", m.port)
  m.video.observeField("streamingSegment", m.port)
end sub
