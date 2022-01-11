' ConvivaClient Version: 3.0.15
' authors: Kedar Marsada <kmarsada@conviva.com>, Mayank Rastogi <mrastogi@conviva.com>
'

'==== Public interface to the ConvivaLivePass library ====
' The code below should be used in the integrations.
'==== Public interface to the ConvivaLivePass library ====

'''
''' ConvivaClient is a singleton that returns ConvivaClientInstance
'''
function ConvivaClient(settings as object)
  globalAA = getGlobalAA()

  if globalAA.ConvivaClient = invalid
    globalAA.ConvivaClient = ConvivaClientInstance(settings)
  end if

  return globalAA.ConvivaClient
end function

'''
''' ConvivaClient class
''' @Params: settings containing gatewayUrl, customerKey
'''
function ConvivaClientInstance(settings as object)
self = {}
self.settings = settings

'Ad technology type'
self.AD_TYPE = {
  CLIENT_SIDE: "Client Side",
  SERVER_SIDE: "Server Side"
}

' Player states'
self.PLAYER_STATE = {
      STOPPED:        "1",
      BUFFERING:      "6",
      PLAYING:        "3",
      PAUSED:        "12"
}

'Error severity'
self.ERROR_SEVERITY = {
  WARNING: false,
  FATAL: true
}

self.VideoNodeIdentifier = createObject("RoSGNode","ContentNode")

' Keeps track of all video nodes currently being monitored along with their corresponding Conviva task instances
self.monitors = []

' Utility function to check if videonode is already being monitored & stored
self.isVideoExists = function(videoNode as object)
  self = m
  if videoNode <> Invalid
    for each monitor in self.monitors
      if monitor.videoNode <> invalid and monitor.videoNode.isSameNode(videoNode)
        return true
      end if
    end for
  end if
  return false
end function

'Utility function to get corresponding conviva task for a given video node
self.getConvivaTask = function(videoNode as object)
self = m
  if videoNode <> invalid
    for each monitor in self.monitors
      if monitor.videoNode <> invalid and monitor.videoNode.isSameNode(videoNode)
        return monitor.convivaTask
      end if
    end for
  end if
  return invalid
end function

'
' monitorVideoNode : Creates conviva task, registers for listeners and starts Conviva session monitoring
' @params: videonode and contentinfo objects
' contentInfo is an associative array consisting of assetname, streamUrl, .. etc metadata about the video
'
self.monitorVideoNode = function(videoNode as object, contentInfo as object)
  self = m
      'Check if videoNode is already being monitored
      if self.isVideoExists(videoNode)
        return invalid
      end if

      'Create Conviva Task
      convivaTask = createObject("roSGNode", "ConvivaPlayerMonitor")
      if videoNode.isSubtype("Video")
        convivaTask.callFunc("monitorNode", videoNode, contentInfo)
      else
        convivaTask.callFunc("monitorNode", invalid, contentInfo)
      end if

      convivaTask.gatewayUrl = self.settings.gatewayUrl
      convivaTask.customerKey = self.settings.customerKey

      convivaTask.control = "RUN"
      if videoNode <> Invalid and videoNode.isSubtype("Video")
        videoNode.appendChild(convivaTask)
      end if
      'Append task to videoNode as child.
      monitor = CreateObject("roAssociativeArray")
      monitor.videoNode = videoNode
      monitor.convivaTask = convivaTask

      'store videoNode
      self.monitors.push(monitor)
      self.log(videoNode, "ConvivaClient monitorVideoNode")
end function

' To associate a videoNode to an existing monitoring session
' To use this API, monitorVideoNode should hav been called with a videonodeidentifier earlier.
self.associateVideoNode = function (videoNode as object)
  self = m
  'Check if videoNode is already being monitored
  if self.isVideoExists(videoNode)
    return invalid
  end if

  convivaTask = self.getConvivaTask(self.VideoNodeIdentifier)
  if videoNode <> Invalid and videoNode.isSubtype("Video")

    ' DE-6578 associate video node issue - Video node was not getting updated to latest
    metadata = {}
    metadata.type = "ConvivaUpdateVideoNode"
    metadata.videoNode = videoNode
    convivaTask.callFunc("dispatchEvent", metadata)

    videoNode.appendChild(convivaTask)
  end if
  'Append task to videoNode as child.
  monitor = CreateObject("roAssociativeArray")
  monitor.videoNode = videoNode
  monitor.convivaTask = convivaTask

  'store videoNode
  self.monitors.clear()
  self.monitors.push(monitor)
  self.log(videoNode, "ConvivaClient associateVideoNode")
end function
'
' To register existing conviva task with client instance to avoid client from recreating a task for monitoring purposes.
' Mainly used when LivePass APIs are used instead of monitorVideoNode for experience insights integrations.
' Conviva client reuses the task to perform Ad insights monitoring using client APIs
'
' @params: videonode: to which conviva task is created
' convivaTask: existing conviva task created in applications for monitoring purposes.
'
self.configureExistingTask = function(videoNode as object, convivaTask as object)
  self = m

  if self.isVideoExists(videoNode)
    return invalid
  end if
  'To use existing task, append task to video node as child & save it
  videoNode.appendChild(convivaTask)
  ' add to monitors
      monitor = CreateObject("roAssociativeArray")
      monitor.videoNode = videoNode
      monitor.convivaTask = convivaTask

      'store videoNode
      self.monitors.push(monitor)
end function

'
' To be used only when you want to end monitoring abruptly - Like click of back button during video playback and at the end of playback
self.endMonitoring = function(videoNode as object)
  self = m
  if self.isVideoExists(videoNode) = false
    return invalid
  end if

  self.log(videoNode, "ConvivaClient endMonitoring")
convivaTask = self.getConvivaTask(videoNode)
if convivaTask <> invalid
  metadata = {}
  metadata.type = "ConvivaCleanupSession"
  convivaTask.callFunc("dispatchEvent", metadata)
end if
  index=0
  for each monitor in self.monitors
    if monitor.videoNode <> invalid and monitor.videoNode.isSameNode(videoNode)
      self.monitors.delete(index)
    end if
    index = index + 1
  end for
end function

' Updates content metadata to a content session for a given video node.
self.setOrUpdateContentInfo = function(videoNode as object, contentInfo as object)
      self = m
      self.log(videoNode, "ConvivaClient setOrUpdateContentInfo")
      if self.isVideoExists(videoNode) = false
      return invalid
      end if

  convivaTask = self.getConvivaTask(videoNode)
  if convivaTask <> invalid
    metadata = contentInfo
    metadata.type = "ConvivaUpdateContentMetadata"
    convivaTask.callFunc("dispatchEvent", metadata)
  end if

end function

' Reports custom error to content session if it exists
' Yet to test reporting error when session does not exist
self.reportContentError = function(videoNode as object, errorMessage as dynamic, severity as boolean)
      self = m
      self.log(videoNode, "ConvivaClient reportContentError")
      if self.isVideoExists(videoNode)
          convivaTask = self.getConvivaTask(videoNode)
          if convivaTask <> invalid
              contentError = {}
              contentError.type = "ConvivaContentError"
              contentError.message = errorMessage
              contentError.severity = severity
              convivaTask.callFunc("dispatchEvent", contentError)
          end if
      end if
  end function

' Reports custom event to a content session
self.reportContentPlayerEvent = function(videoNode as object, eventType as dynamic, eventDetail as object)
      self=m
      self.log(videoNode, "ConvivaClient reportContentPlayerEvent")
  if self.isVideoExists(videoNode)
          convivaTask = self.getConvivaTask(videoNode)
          if convivaTask <> invalid
              contentEvent = {}
              contentEvent.type = "ConvivaContentEvent"
              contentEvent.eventType = eventType
              contentEvent.eventDetail = eventDetail
              convivaTask.callFunc("dispatchEvent", contentEvent)
          end if
      end if
end function

' Pauses monitoring a given video node. Moves content session to NOT_MONITORED state
self.setContentPauseMonitoring = function(videoNode as object)
      self=m
      self.log(videoNode, "ConvivaClient setContentPauseMonitoring")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      contentEvent = {}
      contentEvent.type = "ConvivaContentPauseMonitor"
      convivaTask.callFunc("dispatchEvent", contentEvent)
    end if
  end if
end function

' Resumes monitoring a given video node. Moves content session into MONITORED state'
self.setContentResumeMonitoring = function(videoNode as object)
      self=m
      self.log(videoNode, "ConvivaClient setContentResumeMonitoring")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      contentEvent = {}
      contentEvent.type = "ConvivaContentResumeMonitor"
      convivaTask.callFunc("dispatchEvent", contentEvent)
    end if
  end if
end function

' For a given video node that handles content playback, report ad "loaded" event.
' Creates an ad session associating with the content session that videonode is responsible for
' Keeps ad session in BUFFERING state
' Optional call. Need not be called if ad manager does not expose ad "loaded" event
self.reportAdLoaded = function(videoNode as object, adInfo as object)
      self = m
      self.log(videoNode, "ConvivaClient reportAdLoaded")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      adEvent = adInfo
      adEvent.type = "ConvivaAdLoaded"
      convivaTask.callFunc("dispatchEvent", adEvent)
    end if
  end if
end function

' For a given video node that handles content playback, report ad "start" / "impression" events or similar
' Creates an ad session associating with the content session that videonode is responsible for
' Keeps ad session in PLAYING state
self.reportAdStart = function(videoNode as object, adInfo as object)
      self = m
      self.log(videoNode, "ConvivaClient reportAdStart")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      adEvent = adInfo
      adEvent.type = "ConvivaAdStart"
      convivaTask.callFunc("dispatchEvent", adEvent)
    end if
  end if
end function

' Closes an ad session if it exists
self.reportAdEnded = function(videoNode as object, adInfo as object)
      self = m
      self.log(videoNode, "ConvivaClient reportAdEnded")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      adEvent = adInfo
      adEvent.type = "ConvivaAdComplete"
      convivaTask.callFunc("dispatchEvent", adEvent)
    end if
  end if
end function

' Reports an ad skip to the session if it exists
self.reportAdSkipped = function(videoNode as object, adInfo as object)
      self = m
      self.log(videoNode, "ConvivaClient reportAdSkipped")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      adEvent = adInfo
      adEvent.type = "ConvivaAdSkip"
      convivaTask.callFunc("dispatchEvent", adEvent)
    end if
  end if
end function

' Updates ad metadata for an ad session on a given videonode
self.setOrUpdateAdInfo = function(videoNode as object, contentInfo as object)
      self = m
      self.log(videoNode, "ConvivaClient setOrUpdateAdInfo")
  if self.isVideoExists(videoNode) = false
    return invalid
  end if

  convivaTask = self.getConvivaTask(videoNode)
  if convivaTask <> invalid
    metadata = contentInfo
    metadata.type = "ConvivaUpdateAdMetadata"
    convivaTask.callFunc("dispatchEvent", metadata)
  end if
end function

' For a given video node that handles content playback, report ad playback or load "error"
self.reportAdError = function(videoNode as object, errorMessage as string, severity as boolean)
      self=m
      self.log(videoNode, "ConvivaClient reportAdError")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      adEvent = {}
      adEvent.type = "ConvivaAdError"
      adEvent.errorMessage = errorMessage
      convivaTask.callFunc("dispatchEvent", adEvent)
    end if
  end if
end function

' For a given video node that handles content playback, report a custom event to ad session
self.reportAdPlayerEvent = function(videoNode as object, eventType as string, eventDetail as object)
      self=m
      self.log(videoNode, "ConvivaClient reportAdPlayerEvent")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      adEvent = adInfo
      adEvent.type = "ConvivaAdEvent"
      convivaTask.callFunc("dispatchEvent", adEvent)
    end if
  end if
end function

' Report ad break started to content sessions
' If adType is client side, the API takes care of calling detachStreamer & adStart LivePass APIs
' Report Conviva.PodStart custom event with adBreakInfo to content session'
self.reportAdBreakStarted = function(videoNode as object, adType as string, adBreakInfo as object)
      self=m
      self.log(videoNode, "ConvivaClient reportAdBreakStarted")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      adEvent = adBreakInfo
      adEvent.type = "ConvivaPodStart"
      if adType = self.AD_TYPE.CLIENT_SIDE
        adEvent.technology = "Client Side"
      else
        adEvent.technology = "Server Side"
      end if
      convivaTask.callFunc("dispatchEvent", adEvent)
    end if
  end if
end function

' Report ad break ended to content sessions
' If adType is client side, the API takes care of calling attachStreamer & adend LivePass APIs
' Report Conviva.PodEnd custom event with adBreakInfo to content session'
self.reportAdBreakEnded = function(videoNode as object, adType as string, adBreakInfo as object)
      self=m
      self.log(videoNode, "ConvivaClient reportAdBreakEnded")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      adEvent = adBreakInfo
      adEvent.type = "ConvivaPodEnd"
      if adType = self.AD_TYPE.CLIENT_SIDE
        adEvent.technology = "Client Side"
      else
        adEvent.technology = "Server Side"
      end if
      convivaTask.callFunc("dispatchEvent", adEvent)
    end if
  end if
end function

' TBD - incomplete implementation - Will never be used. Created the API to keep it consistent across all platforms
self.reportPlayerState = function( videoNode as object, playerState as string )
      self=m
  return invalid
end function

' Reports a play state to ad session that is being handled by the given videoNode
self.reportAdPlayerState = function( videoNode as object, playerState as string )
      self=m
      self.log(videoNode, "ConvivaClient reportAdPlayerState")
  if self.isVideoExists(videoNode)
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      adEvent = {}
      adEvent.playerState = playerState
      adEvent.type = "ConvivaAdPlayerState"
      convivaTask.callFunc("dispatchEvent", adEvent)
    end if
  end if
end function

' Reports current playing bitrate to content session. This API must be used if auto-detection by library fails
self.reportPlayerBitrate = function(videoNode as object, bitrate as integer)
  self=m
  self.log(videoNode, "ConvivaClient reportPlayerBitrate")
  convivaTask = self.getConvivaTask(videoNode)
  if convivaTask <> invalid
    event = {}
    event.bitrate = bitrate
    event.type = "ConvivaContentBitrate"
    convivaTask.callFunc("dispatchEvent", event)
  end if
end function

' Reports current playing bitrate to ad session.
self.reportAdPlayerBitrate = function(videoNode as object, bitrate as integer)
      self=m
      self.log(videoNode, "ConvivaClient reportAdPlayerBitrate")
  convivaTask = self.getConvivaTask(videoNode)
  if convivaTask <> invalid
    adEvent = {}
    adEvent.bitrate = bitrate
    adEvent.type = "ConvivaAdBitrate"
    convivaTask.callFunc("dispatchEvent", adEvent)
  end if
end function

' Reports to content session that seek start is detected
self.reportSeekStarted = function( videoNode as object, seekToPosMs as integer)
      self=m
      self.log(videoNode, "ConvivaClient reportSeekStarted")
      convivaTask = self.getConvivaTask(videoNode)
      if convivaTask <> invalid
      contentEvent = {}
      contentEvent.seekPos = seekToPosMs
      contentEvent.type = "ConvivaContentSeekStart"
      convivaTask.callFunc("dispatchEvent", contentEvent)
      end if
end function

' Reports to content session that seek end is detected
self.reportSeekEnd = function(videoNode as object)
      self=m
      self.log(videoNode, "ConvivaClient reportSeekEnd")
      convivaTask = self.getConvivaTask(videoNode)
      if convivaTask <> invalid
      contentEvent = {}
      contentEvent.type = "ConvivaContentSeekEnd"
      convivaTask.callFunc("dispatchEvent", contentEvent)
      end if
end function

' TBD - Incomplete implementation
' Reports a custom event to a global session
self.reportAppEvent = function(videoNode as object, eventType as string, eventDetail as object)
      self=m
      self.log(videoNode, "ConvivaClient reportAppEvent")
      convivaTask = self.getConvivaTask(videoNode)
      if convivaTask <> invalid
          globalEvent = {}
          globalEvent.type = "ConvivaGlobalEvent"
          globalEvent.eventType = eventType
          globalEvent.eventDetail = eventDetail
          convivaTask.callFunc("dispatchEvent", globalEvent)
      end if
  end function

' Monitors & integrates ad insights with Roku ads framework (CSAI only)
  self.monitorRaf = function(videoNode as object, rafInstance as object)
      self = m
      self.log(videoNode, "ConvivaClient monitorRaf")
      convivaTask = self.getConvivaTask(videoNode)
      if convivaTask <> invalid
    tempObj = {}
    tempObj.self = self
    tempObj.videoNode = videoNode
    tempObj.rafVersion = rafInstance.getLibVersion()
    rafInstance.setTrackingCallback(self.rafAdTrackingCallback, tempObj)
    rafInstance.setAdBufferRenderCallback(self.rafAdBufferCallback, tempObj)
  end if
end function

' Monitors & integrates ad insights with Google DAI
' @params: videoNode that is responsible for ad playback
' streamManager instance created by Google DAI SDK.
self.monitorGoogleDAI = function(videoNode as object, sdkInstance as object)
      self = m
      self.log(videoNode, "ConvivaClient monitorGoogleDAI")
      convivaTask = self.getConvivaTask(videoNode)
      if convivaTask <> invalid and sdkInstance <> invalid
      streamManager = sdkInstance.getStreamManager()
      self.convivaDaiVideoNode = videoNode
      streamManager.addEventListener(sdkInstance.AdEvent.ERROR, self.daiError)
      streamManager.addEventListener(sdkInstance.AdEvent.START, self.daiStart)
      streamManager.addEventListener(sdkInstance.AdEvent.FIRST_QUARTILE, self.daiFirstQuartile)
      streamManager.addEventListener(sdkInstance.AdEvent.MIDPOINT, self.daiMidpoint)
      streamManager.addEventListener(sdkInstance.AdEvent.THIRD_QUARTILE, self.daiThirdQuartile)
      streamManager.addEventListener(sdkInstance.AdEvent.COMPLETE, self.daiComplete)
      end if
end function

' Monitors & integrates ad insights with YoSpace Ad Management SDK
' @params: videoNode that is responsible for ad playback
' yoSpaceSession: session instance created by YoSpace ad management SDK.
self.monitorYoSpaceSDK = function(videoNode as object, yoSpaceSession as object)
      self = m
      self.log(videoNode, "ConvivaClient monitorYoSpaceSDK")
      convivaTask = self.getConvivaTask(videoNode)
      if convivaTask <> invalid and yoSpaceSession <> invalid
      self.convivaYoSpaceVideoNode = videoNode
      self.convivaYoSpaceSession = yoSpaceSession
      if yoSpaceSession.observeField <> invalid
          'yoSpaceSession.observeField("PlaybackURL", "self.OnPlaybackURL")
          'yoSpaceSession.observeField("AdBreakStart", "self.OnYoSpaceAdBreakStart")
          'yoSpaceSession.observeField("AdBreakEnd", "self.OnAdBreakEnd")
          'yoSpaceSession.observeField("AdvertStart", "self.OnAdvertStart")
          'yoSpaceSession.observeField("AdvertEnd", "self.OnAdvertEnd")
          'yoSpaceSession.observeField("Timeline", "self.OnTimelineUpdated")
      else
          player    = {}
          player["AdBreakStart"]    = yo_Callback(self.OnYoSpaceAdBreakStart, m)
          player["AdvertStart"]     = yo_Callback(self.OnYoSpaceAdStart, m)
          player["AdvertEnd"]       = yo_Callback(self.OnYoSpaceAdEnd, m)
          player["AdBreakEnd"]      = yo_Callback(self.OnYoSpaceAdBreakEnd, m)

          yoSpaceSession.RegisterPlayer(player)
      end if
      end if
end function

' Monitors & integrates ad insights with RAFX SSAI Adapters
' @params: videoNode that is responsible for ad playback
' adapter: instance returned from RAFX_SSAI() API. Works for all SSAI adapters supported by RAFX
self.monitorRAFX = function(videoNode as object, adapter as object)
      self = m
      self.log(videoNode, "ConvivaClient monitorRAFX")
      convivaTask = self.getConvivaTask(videoNode)
      if convivaTask <> invalid and adapter <> invalid
      self.convivaRafxVideoNode = videoNode
      self.convivaRafxAdapter = adapter
      'adapter.addEventListener(adapter.AdEvent.PODS, self.rafxPodStart)
      adapter.addEventListener(adapter.AdEvent.POD_START, self.rafxPodStart)
      adapter.addEventListener(adapter.AdEvent.IMPRESSION, self.rafxAdEvent)
      adapter.addEventListener(adapter.AdEvent.FIRST_QUARTILE, self.rafxAdEvent)
      adapter.addEventListener(adapter.AdEvent.MIDPOINT, self.rafxAdEvent)
      adapter.addEventListener(adapter.AdEvent.THIRD_QUARTILE, self.rafxAdEvent)
      adapter.addEventListener(adapter.AdEvent.COMPLETE, self.rafxAdEvent)
      adapter.addEventListener(adapter.AdEvent.POD_END, self.rafxPodEnd)
      end if
end function

' Utility method used by RAF ad insights API: monitorRaf
self.rafAdTrackingCallback = function(obj=Invalid as Dynamic, eventType = Invalid as Dynamic, ctx = Invalid as Dynamic)
    self = obj.self
    adMetadata = {}
    adMetadata.SetModeCaseSensitive()
    if eventType = "PodStart" then
    if ctx.rendersequence = "preroll"
        adMetadata["podPosition"] = "Pre-roll"
    else if ctx.rendersequence = "midroll"
        adMetadata["podPosition"] = "Mid-roll"
    else if ctx.rendersequence = "postroll"
        adMetadata["podPosition"] = "Post-roll"
    else
        adMetadata["podPosition"] = "Unknown"
    end if
      self.reportAdBreakStarted(obj.videoNode, self.AD_TYPE.CLIENT_SIDE, adMetadata)
      else if eventType = "PodComplete" then
    if ctx.rendersequence = "preroll"
        adMetadata["podPosition"] = "Pre-roll"
    else if ctx.rendersequence = "midroll"
        adMetadata["podPosition"] = "Mid-roll"
    else if ctx.rendersequence = "postroll"
        adMetadata["podPosition"] = "Post-roll"
    else
        adMetadata["podPosition"] = "Unknown"
    end if
        self.reportAdBreakEnded(obj.videoNode, self.AD_TYPE.CLIENT_SIDE, adMetadata)
    else if eventType = "Start" then
        adMetadata.assetName = "No ad title"
        if ctx.ad.adtitle <> invalid and Len(ctx.ad.adtitle.trim()) <> 0
          adMetadata.assetName = ctx.ad.adtitle
        end if
        adMetadata.contentLength = Int(ctx.ad.duration)

        adMetadata.adid = ctx.ad.adid
        adMetadata.adsystem = "NA"
        adMetadata.mediaFileApiFramework = "NA"
        adMetadata.sequence = stri(ctx.adindex).trim()
        adMetadata.technology = self.AD_TYPE.CLIENT_SIDE
        if ctx.rendersequence = "preroll"
          adMetadata.position = "Pre-roll"
        else if ctx.rendersequence = "midroll"
          adMetadata.position = "Mid-roll"
        else if ctx.rendersequence = "postroll"
          adMetadata.position = "Post-roll"
        end if
        adMetadata.creativeId = ctx.ad.creativeid
        adMetadata.adManagerName = "Roku ads framework"
        adMetadata.adManagerVersion = obj.rafVersion
        adMetadata.sessionStartEvent = "start"
        adMetadata.moduleName = "RC"
        adMetadata.advertiser = ctx.ad.advertiser
        adMetadata.streamUrl = ctx.ad.streams[0].url
          adMetadata.isLive = false
        self.reportAdStart(obj.videoNode, adMetadata)
    else if eventType = "Complete" then
        self.reportAdEnded(obj.videoNode, adMetadata)
      else if eventType = "Pause" then
        self.reportAdPlayerState(obj.videoNode, self.PLAYER_STATE.PAUSED)
      else if eventType = "Resume" then
        self.reportAdPlayerState(obj.videoNode, self.PLAYER_STATE.PLAYING)
    else if eventType = "Error" then
        errMsg = ctx.errMsg + " - " + ctx.errCode
        self.reportAdError(obj.videoNode, errMsg, 1)
    end if

  'end if
end function

' Utility function used by monitorRaf
self.rafAdBufferCallback = function(obj=Invalid as Dynamic, eventType = Invalid as Dynamic, ctx = Invalid as Dynamic)
  self = obj.self
  if eventType = "BufferingStart" or eventType="ReBufferingStart"
    self.reportAdPlayerState(obj.videoNode, self.PLAYER_STATE.BUFFERING)
  else if eventType = "BufferingEnd" or eventType="ReBufferingEnd"
    self.reportAdPlayerState(obj.videoNode, self.PLAYER_STATE.PLAYING)
  end if
end function

'Internal to Google DAI module'
self.daiStart = function (ad as object)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient
  ad.eventType = "Start"
  adInfo = self.constructDaiMetadata(ad)
  podInfo = {}
  podInfo.SetModeCaseSensitive()
  podInfo["podPosition"] = "NA"
  podInfo["podDuration"] = ad.adbreakinfo.duration
  self.reportAdBreakStarted(self.convivaDaiVideoNode, self.AD_TYPE.SERVER_SIDE, podInfo)
  self.reportAdStart(self.convivaDaiVideoNode, adInfo)
end function
'Internal to Google DAI module'
self.daiFirstQuartile = function (ad as object)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient
  ad.eventType = "FirstQuartile"
  adInfo = self.constructDaiMetadata(ad)
  self.reportAdStart(self.convivaDaiVideoNode, adInfo)
end function
'Internal to Google DAI module'
self.daiMidpoint = function (ad as object)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient
  ad.eventType = "MidPoint"
  adInfo = self.constructDaiMetadata(ad)
  self.reportAdStart(self.convivaDaiVideoNode, adInfo)
end function
'Internal to Google DAI module'
self.daiThirdQuartile = function (ad as object)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient
  ad.eventType = "ThirdQuartile"
  adInfo = self.constructDaiMetadata(ad)
  self.reportAdStart(self.convivaDaiVideoNode, adInfo)
end function

'Internal to Google DAI module'
self.daiComplete = function (ad as object)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient
  ad.eventType = "Complete"
  adInfo = self.constructDaiMetadata(ad)
  self.reportAdEnded(self.convivaDaiVideoNode, adInfo)
  podInfo = {}
  podInfo.SetModeCaseSensitive()
  podInfo["podPosition"] = "NA"
  podInfo["podDuration"] = ad.adbreakinfo.duration
  self.reportAdBreakEnded(self.convivaDaiVideoNode, self.AD_TYPE.SERVER_SIDE, podInfo)
end function

'Internal to Google DAI module'
self.constructDaiMetadata = function (adData as object)
  adInfo = {}
  adInfo.SetModeCaseSensitive()
  assetName = "No assetname detected"
  adDuration = 0
  if adData.adid <> invalid
    adInfo.adid = adData.adid
    adInfo.adsystem = adData.adsystem
    adInfo.adStitcher = "Google DAI"
    adInfo.sequence = stri(adData.adbreakinfo.adposition)
    adInfo.assetName = adData.adtitle
    adInfo.contentLength = Int(adData.duration)
  else
    adInfo.adid = "NA"
    adInfo.adsystem = "NA"
    adInfo.adStitcher = "NA"
    adInfo.sequence = "NA"
  end if
  adInfo.technology = "Server Side"
  adInfo.position = "NA"
  adInfo.mediaFileApiFramework = "NA"
  adInfo.adManagerName = "Google IMA DAI SDK"
  adInfo.adManagerVersion = "3.28.1"
  adInfo.sessionStartEvent = ""+adData.eventType
  adInfo.advertiser = ""+adData.advertisername
  adInfo.moduleName = "GD"
  if adData.wrappers.count() > 0 or adData.wrappers = invalid
    adInfo.servingType = "Wrapper"
  else
    adInfo.servingType = "Inline"
  end if
  return adInfo
end function

self.daiError = function (adData as object)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient
  errorMessage = "Error code:"+adData.id+" Error Message: "+adData.info
  self.reportAdError(self.convivaDaiVideoNode, errorMessage, self.ERROR_SEVERITY.FATAL)
end function

self.rafxPodStart = function (podInfo as Object)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient

  m.rafxAdPod = podInfo["adPod"]
  m.rafxAdIndex = 0

  adMetadata = {}
  adMetadata.SetModeCaseSensitive()
  adMetadata.podDuration = podInfo["adPod"].duration
  if podInfo["adPod"].rendersequence = "preroll"
    adMetadata["podPosition"] = "Pre-roll"
  else if podInfo["adPod"].rendersequence = "midroll"
    adMetadata["podPosition"] = "Mid-roll"
  else
    adMetadata["podPosition"] = "Post-roll"
  end if
  self.reportAdBreakStarted(self.convivaRafxVideoNode, self.AD_TYPE.SERVER_SIDE, adMetadata)
end function

self.rafxPodEnd = function (podInfo as Object)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient
  adMetadata = {}
  adMetadata.SetModeCaseSensitive()
  self.reportAdBreakEnded(self.convivaRafxVideoNode, self.AD_TYPE.SERVER_SIDE, adMetadata)
end function

self.rafxAdEvent = function (adInfo as object)
  adData = m.rafxAdPod.ads[m.rafxAdIndex]
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient

  if adInfo.event = "Start" or adInfo.event = "Impression"
    adInfo = {}
    adInfo.SetModeCaseSensitive()

    if adData.adtitle <> invalid
      adInfo.assetName = adData.adtitle
    else
      adInfo.assetName = "No assetname detected"
    end if
    adInfo.adid = adData.adid
    adInfo.adsystem = adData.adserver
    adInfo.technology = "Server Side"
    adInfo.creativeId = adData.creativeid
    adInfo.adManagerName = "RAFX SSAI Adapter"
    adInfo.adManagerVersion = self.convivaRafxAdapter["__version__"]
    adInfo.sessionStartEvent = "Impression"
    adInfo.adStitcher = "Uplynk"
    adInfo.isSlate = "false"
    adInfo.mediaFileApiFramework = "NA"
    if m.rafxAdPod.rendersequence = "preroll"
      adInfo.position = "Pre-roll"
    else if m.rafxAdPod.rendersequence = "midroll"
      adInfo.position = "Mid-roll"
    else if m.rafxAdPod.rendersequence = "postroll"
      adInfo.position = "Post-roll"
    end if
    if adData.streams.count() > 0
      adInfo.streamUrl = adData.streams[0].url
    end if
    adInfo.contentLength = Int(adData.duration)
    adInfo.defaultReportingResource = ""
    adInfo.streamFormat = "hls"
    adInfo.moduleName = "RS"
    self.reportAdStart(self.convivaRafxVideoNode, adInfo)
  else if adInfo.event = "Complete" then
    self.reportAdEnded(self.convivaRafxVideoNode, adInfo)
    m.rafxAdIndex += 1
  end if
end function

self.OnYoSpaceAdBreakStart = function (breakInfo = invalid as Dynamic)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient

  adMetadata = {}
  adMetadata.SetModeCaseSensitive()
  if breakInfo.GetStart() = 0 and self.convivaYoSpaceSession <> invalid and self.convivaYoSpaceSession._CLASSNAME <> "YSLiveSession"
      adMetadata["podPosition"] = "Pre-roll"
  else
      adMetadata["podPosition"] = "Mid-roll"
  end if
  adMetadata["podDuration"] = breakInfo.GetDuration()

  self.reportAdBreakStarted(self.convivaYoSpaceVideoNode, self.AD_TYPE.SERVER_SIDE, adMetadata)
end function

self.OnYoSpaceAdBreakEnd = function (breakInfo = invalid as Dynamic)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient
  adMetadata = {}
  adMetadata.SetModeCaseSensitive()
  self.reportAdBreakEnded(self.convivaYoSpaceVideoNode, self.AD_TYPE.SERVER_SIDE, adMetadata)
end function

self.OnYoSpaceAdStart = function (adData = invalid as Dynamic)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient
  adInfo = {}
  adInfo.SetModeCaseSensitive()
  if self.convivaYoSpaceSession <> invalid
    advert = self.convivaYoSpaceSession.GetCurrentAdvert()
    if (advert <> invalid)
        if (advert<> invalid)
            adInfo.adid = advert.GetAdvertID()
            if advert.GetProperty("AdSystem") <> invalid then adInfo.adsystem = advert.GetProperty("AdSystem").GetValue()
            if advert.GetProperty("AdTitle") <> invalid then adInfo.assetName = advert.GetProperty("AdTitle").GetValue()
            if advert.GetProperty("Advertiser") <> invalid then adInfo.advertiser = advert.GetProperty("Advertiser").GetValue()
            
            ' CSR-4960 fix for sequence
            if advert.GetSequence() <> invalid
            adInfo.sequence = advert.GetSequence().toStr()
            end if
        end if
        if advert.isFiller() = true
            adInfo.isSlate = "true"
        else
            adInfo.isSlate = "false"
        end if

        if (self.convivaYoSpaceSession.GetCurrentAdBreak()<> invalid and self.convivaYoSpaceSession.GetCurrentAdBreak().GetStart() = 0 and self.convivaYoSpaceSession._CLASSNAME <> "YSLiveSession")
            adInfo.position = "Pre-roll"
        else
            adInfo.position = "Mid-roll"
        end if
        adInfo.creativeId = advert.GetLinearCreative()
        adInfo.contentLength = Int(advert.GetDuration())
    end if
    if self.convivaYoSpaceSession._CLASSNAME <> "YSLiveSession"
        adInfo.isLive = false
    else
        adInfo.isLive = true
    end if
  end if
  adInfo.streamUrl = self.convivaYoSpaceSession.GetPlaybackUrl()
  adInfo.mediaFileApiFramework = "NA"
  adInfo.technology = "Server Side"
  adInfo.streamFormat = self.convivaYoSpaceSession._data.streamtype
  adInfo.adManagerName = "YoSpace SDK"
  adInfo.adManagerVersion = yo_vers_get()
  adInfo.adstitcher = "YoSpace CSM"
  adInfo.moduleName = "YS"
  self.reportAdStart(self.convivaYoSpaceVideoNode, adInfo)
end function

self.OnYoSpaceAdEnd = function(adData = invalid as Dynamic)
  globalAA = getGlobalAA()
  self = globalAA.ConvivaClient
  adInfo = {}
  self.reportAdEnded(self.convivaYoSpaceVideoNode, adInfo)
end function

self.setCDNServerIP = function (videoNode as object, cdnServerIPAddress as string)
  self=m
  self.log(videoNode, "ConvivaClient setCDNServerIP")
  convivaTask = self.getConvivaTask(videoNode)
  if convivaTask <> invalid
    event = {}
    event.cdnServerIPAddress = cdnServerIPAddress
    event.type = "ConvivaCDNServerIP"
    convivaTask.callFunc("dispatchEvent", event)
  end if
end function

self.log = function (videoNode as object, msg as string)
  self = m
  convivaTask = self.getConvivaTask(videoNode)
  if convivaTask <> invalid
    event = {}
    event.msg = msg
    event.type = "ConvivaLog"
    convivaTask.callFunc("dispatchEvent", event)
  end if
end function


return self
end function
