sub init()
  m.top.functionName = "internalInit"
  m.port = CreateObject("roMessagePort")
  m.LivePass = invalid
  m.cSession = invalid
  m.DEBUG = false
  m.video = invalid
  m.playbackStarted = false
end sub

sub internalInit()
  m.DEBUG = m.top.config.debuggingEnabled
  debugLog("[ConvivaAnalytics] setting up")

  apiKey = m.top.customerKey
  if m.top.config.gatewayUrl <> invalid
    cfg = {}
    cfg.gatewayUrl = m.top.config.gatewayUrl
    m.LivePass = ConvivaLivePassInitWithSettings(apiKey, cfg)
  else
    m.LivePass = ConvivaLivePassInitWithSettings(apiKey)
  end if

  m.video = m.top.player.findNode("MainVideo")
  registePlayerEvents()
  monitorVideo()
end sub

sub monitorVideo()
  debugLog("[ConvivaAnalytics] start video element monitoring")
  while true
    msg = ConvivaWait(0, m.port, invalid)
    if type(msg) = "roSGNodeEvent"
      field = msg.getField()
      data = msg.getData()

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
  contentInfo = fetchContentInfo()

  notificationPeriod = m.video.notificationinterval
  m.cSession = m.LivePass.createSession(true, contentInfo, notificationPeriod, m.video)
  debugLog("[ConvivaAnalytics] start session")
end sub

sub endSession()
  m.livePass.cleanupSession(m.cSession)
  m.cSession = invalid
end sub

function isSessionActive()
  return m.cSession <> invalid
end function

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

sub registePlayerEvents()
  ' Passing everything to m.port so that conviva can intercept and track them
  m.top.player.observeField(m.top.player.BitmovinFields.SEEK, m.port)
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

sub setContentMetaData(contentMetadata)
  metaData = ConvivaContentInfo()
  newContentMetadata = {}

  if metaData.assetName <> invalid then newContentMetadata.AddReplace("assetName", contentMetadata.assetName)
  if not m.playbackStarted
    if contentMetadata.viewerid <> invalid then newContentMetadata.AddReplace("viewerid", contentMetadata.viewerid)
    if contentMetadata.streamType <> invalid then newContentMetadata.AddReplace("streamType", contentMetadata.streamType)
    if contentMetadata.playerName <> invalid then newContentMetadata.AddReplace("playerName", contentMetadata.playerName)
    if contentMetadata.contentLength <> invalid then newContentMetadata.AddReplace("contentLength", contentMetadata.contentLength)
    if contentMetadata.customTags <> invalid then newContentMetadata.AddReplace("customTags", contentMetadata.customTags)
  end if
  if contentMetadata.resource <> invalid then newContentMetadata.AddReplace("resource", contentMetadata.resource)
  if contentMetadata.streamUrl <> invalid then newContentMetadata.AddReplace("streamUrl", contentMetadata.streamUrl)
  if contentMetadata.bitrate <> invalid then newContentMetadata.AddReplace("bitrate", contentMetadata.bitrate)
  if contentMetadata.encodedFramerate <> invalid then newContentMetadata.AddReplace("encodedFramerate", contentMetadata.encodedFramerate)

  metaData.Append(newContentMetadata)
  m.livePass.updateContentMetadata(m.cSession, metaData)
end sub

sub debugLog(message as String)
  if m.DEBUG then ?message
end sub
