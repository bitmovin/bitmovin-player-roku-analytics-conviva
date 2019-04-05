sub init()
  m.top.functionName = "internalInit"
  m.port = CreateObject("roMessagePort")
  m.LivePass = invalid
  m.cSession = invalid
  m.DEBUG = false
  m.video = invalid
  m.playbackStarted = false

  m.contentMetadataBuilder = CreateObject("roSGNode", "ContentMetadataBuilder")
end sub

sub internalInit()
  debugLog("[ConvivaAnalytics] setting up")

  m.video = m.top.player.findNode("MainVideo")
  m.DEBUG = m.top.config.debuggingEnabled

  apiKey = m.top.customerKey
  if m.top.config.gatewayUrl <> invalid
    cfg = {}
    cfg.gatewayUrl = m.top.config.gatewayUrl
    m.LivePass = ConvivaLivePassInitWithSettings(apiKey, cfg)
  else
    m.LivePass = ConvivaLivePassInitWithSettings(apiKey)
  end if

  registePlayerEvents()
  monitorVideo()
end sub

sub updateContentMetadata(metadataOverrides)
  m.contentMetadataBuilder.callFunc("setOverrides", metadataOverrides)

  if isSessionActive()
    buildContentMetadata()
    updateSession()
  end if
end sub

sub monitorVideo()
  debugLog("[ConvivaAnalytics] start video element monitoring")
  while true
    msg = ConvivaWait(0, m.port, invalid)
    if type(msg) = "roSGNodeEvent"
      field = msg.getField()
      data = msg.getData()
      ' if m.DEBUG then print chr(10) + "New Event caught" + chr(10) + "Field: "; field + chr(10) +  "Data: "; data

      if field = "seek"
        onSeek()
      else if field = "play"
        onPlay()
      else if field = "state"
        onStateChanged(data)
      end if
    end if
  end while
end sub

sub onStateChanged(state)
  debugLog("[ConvivaAnalytics] state changed: " + state)
  if state = "error"
    onError()
  else if state = "finished"
    onPlaybackFinished()
  end if
  ' Other states are handled by conviva
end sub

sub onPlaybackFinished()
  endSession()
end sub

sub onError()
  ' create a new session to track VSF
  if not isSessionActive() then createSession()
  m.livePass.reportError(m.cSession, "Error", m.livePass.StreamerError.SEVERITY_FATAL)
  endSession()
end sub

sub onPlay()
  debugLog("[Player Event] onPlay")

  if not isSessionActive()
    createConvivaSession()
  end if
end sub

sub onPlaying()
  debugLog("[Player Event] onPlaying")
  m.playbackStarted = true
end sub

sub onSeek()
  debugLog("[Player Event] onSeek")
  m.LivePass.setPlayerSeekStart(m.cSession, -1)
end sub

sub createConvivaSession()
  notificationPeriod = 1.0
  buildContentMetadata()
  m.cSession = m.LivePass.createSession(true, m.contentMetadataBuilder.callFunc("build"), notificationPeriod, m.video)

  m.video.notificationinterval = notificationPeriod
  debugLog("[ConvivaAnalytics] start session")
end sub

sub endSession()
  m.livePass.cleanupSession(m.cSession)
  m.cSession = invalid
end sub

function isSessionActive()
  return m.cSession <> invalid
end function

sub buildContentMetadata()
  m.contentMetadataBuilder.callFunc("setDuration", m.video.duration)
  m.contentMetadataBuilder.callFunc("setStreamType", m.top.player.callFunc("isLive"))

  internalCustomTags = {
    integrationVersion: "1.0.0"
  }

  config = m.top.player.callFunc("getConfig")
  if config.playback <> invalid and config.playback.autoplay <> invalid
    internalCustomTags.autoplay = ToString(config.playback.autoplay)
  end if

  if config.adaptation <> invalid and config.adaptation.preload <> invalid
    internalCustomTags.preload = ToString(config.adaptation.preload)
  end if

  m.contentMetadataBuilder.callFunc("setCustom", internalCustomTags)

  source = config.source
  if source <> invalid
    buildSourceRelatedMetadata(source)
  end if

end sub

sub buildSourceRelatedMetadata(source)
  if source.title <> invalid
    m.contentMetadataBuilder.callFunc("setAssetName", source.title)
  else
    m.contentMetadataBuilder.callFunc("setAssetName", "Untitled (no source.title set)")
  end if

  m.contentMetadataBuilder.callFunc("setViewerId", m.contentMetadataBuilder.callFunc("getViewerId"))
  m.contentMetadataBuilder.callFunc("setStreamUrl", m.video.content.url)
end sub

sub updateSession()
  if not isSessionActive() then return

  m.LivePass.updateContentMetadata(m.cSession, m.contentMetadataBuilder.callFunc("build"))
end sub

sub registePlayerEvents()
  ' Passing everything to m.port so that conviva can intercept and track them
  m.top.player.observeField(m.top.player.BitmovinFields.SEEK, m.port)
  ' TODO: WE NEED TO CHECK PLAY HERE in case of autoplay we have a race condition that we miss the play event
  m.top.player.observeField(m.top.player.BitmovinFields.PLAY, m.port)

  ' Auto collected by conviva within ConvivaWait.
  m.video.observeField("streamInfo", m.port)
  m.video.observeField("state", m.port)
  m.video.observeField("position", m.port)
  m.video.observeField("duration", m.port)
  m.video.observeField("streamingSegment", m.port)
  m.video.observeField("errorCode", m.port)
  m.video.observeField("errorMsg", m.port)
  m.video.observeField("downloadedSegment", m.port)
end sub

sub debugLog(message as String)
  if m.DEBUG then ?message
end sub
