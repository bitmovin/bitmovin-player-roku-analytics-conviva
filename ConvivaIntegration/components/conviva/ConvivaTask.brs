' ConvivaTask Version: 3.3.0
' authors: Kedar Marsada <kmarsada@conviva.com>, Mayank Rastogi <mrastogi@conviva.com>
'
' Monitors node provided as parameter.
' Expects a video node to be passed as "node" along with metadata as "nodedata"'
sub monitorNode(node as object, nodeData as object)
    if node <> invalid and node.isSubtype("Video")
      fields = node.getFields()
      for each field in fields
        node.observeField(field, m.port)
      end for
      m.top.myvideo = node
    end if
    if nodeData <> invalid
      m.top.metadata = nodeData
    end if
end sub

sub updateVideoNode(node as object)
  if node <> invalid and node.isSubtype("Video")
    fields = node.getFields()
    for each field in fields
      node.observeField(field, m.port)
    end for
    m.top.myvideo = node
  end if
end sub

' Dispatch event method is used to dispatch any conviva custom event to the event loop
sub dispatchEvent(event as object)
  m.top.event = event
end sub

' Task initialization
sub init()
  'Create port to listen to events / messages from other threads
  m.port = CreateObject("roMessagePort")
  m.top.observeField("event", m.port)
  'm.top.observeField("myvideo", m.port)
  m.podIndex = 1
  m.top.functionName = "startMonitor"
End Sub

' Starts monitoring video node.
' Creates event loop and waits for events
sub startMonitor()
  m.sessionOptions = {}
  m.sessionOptions["externalErrorReporting"] = m.top.disableErrorReporting
    ' By default switching off all logs to avoid performance issues'
  initConvivaCore(m.top.customerKey, m.top.gatewayUrl, false)
  'if m.top.myvideo <> Invalid

    ' DE-7608 - Do not default assetname to any pre-defined string. better to keep it invalid
    assetName = invalid
    if m.top.metadata.assetName <> invalid
      assetName = m.top.metadata.assetName
    end if
    if m.top.myvideo <> invalid and m.top.myvideo.content <> invalid and assetName = invalid
      assetName = m.top.myvideo.content.title
    end if

    contentInfo = ConvivaContentInfo(assetName, m.top.metadata.customMetadata)
    if m.top.metadata.streamUrl <> invalid or m.top.metadata.streamUrl = ""
      contentInfo.streamUrl = m.top.metadata.streamUrl
    else if m.top.myvideo <> invalid and m.top.myvideo.content <> invalid
      contentInfo.streamUrl = m.top.myvideo.content.url
    end if
    m.contentStreamUrl = contentInfo.streamUrl
    contentInfo.playerName = m.top.metadata.playerName
    contentInfo.isLive = m.top.metadata.isLive
    contentInfo.viewerId = m.top.metadata.viewerId
    contentInfo.contentLength = m.top.metadata.contentLength
    contentInfo.defaultReportingResource = m.top.metadata.defaultReportingResource
    contentInfo.encodedFramerate = m.top.metadata.encodedFramerate
    contentInfo.streamFormat = m.top.metadata.streamFormat

    ' CSR-4909 fix to accept notification interval set by customer or default it to 0.5
    if (m.top.myvideo = invalid  or (m.top.myvideo <> invalid and (m.top.myvideo.notificationInterval = invalid or m.top.myvideo.notificationInterval > 1))) then
      m.notificationInterval = 0.5 ' 0.5 is the new standard from Roku for notification interval
    else
      m.notificationInterval = m.top.myvideo.notificationInterval
    end if
    m.contentSession = m.LivePass.createSession(true, contentInfo, m.notificationInterval, m.top.myvideo, m.sessionOptions)
    m.LivePass.detachStreamer()
    m.LivePass.adStart()
  'end if

  while(true)
    if m.LivePass <> invalid
      msg = ConvivaWait(0, m.port, invalid)
    else
      msg = wait(0, m.port)
    end if
    msgType = type(msg)
    ' CSR-3909 fixes creation of multiple sessions if task that owns video node is destroyed and monitorVideoNode is called again.
    ' monitorVideoNode must be called for every asset.
    if msgType = "roUrlEvent"
      if m.LivePass.isCleanupContentSessionSuccessful()
        exit while
      end if
    end if

    if msgType = "roSGNodeEvent"
      if msg.GetField() = "state" then
        print "msgType="+msgType + "       getField="+msg.GetField() + "       data="+(msg.GetData())
      else if msg.GetField() = "control" then
        if msg.GetData() = "play" then
          if m.contentSession <> invalid
            m.LivePass.adEnd()
            m.LivePass.attachStreamer()
          else
            if m.contentSession = invalid
              assetName = ""
              if assetName = "" and m.top.metadata.assetName <> invalid
                assetName = m.top.metadata.assetName
              end if
              if m.top.myvideo.content <> invalid and assetName = ""
                assetName = m.top.myvideo.content.title
              end if
              if assetName = ""
                assetName = "No assetName detected"
              end if
              contentInfo = ConvivaContentInfo(assetName, m.top.metadata.customMetadata)
              if m.top.metadata.streamUrl <> invalid or m.top.metadata.streamUrl = ""
                contentInfo.streamUrl = m.top.metadata.streamUrl
              else if m.top.myvideo.content <> invalid
                contentInfo.streamUrl = m.top.myvideo.content.url
              end if
              m.contentStreamUrl = contentInfo.streamUrl

              contentInfo.playerName = m.top.metadata.playerName
              contentInfo.isLive = m.top.metadata.isLive
              contentInfo.viewerId = m.top.metadata.viewerId
              contentInfo.contentLength = m.top.metadata.contentLength
              contentInfo.defaultReportingResource = m.top.metadata.defaultReportingResource
              contentInfo.encodedFramerate = m.top.metadata.encodedFramerate
              contentInfo.streamFormat = m.top.metadata.streamFormat

              ' CSR-4909 fix to accept notification interval set by customer
              if (m.top.myvideo = invalid  or (m.top.myvideo <> invalid and (m.top.myvideo.notificationInterval = invalid or m.top.myvideo.notificationInterval > 1))) then
                m.notificationInterval = 0.5 ' 0.5 is the new standard from Roku for notification interval
              else
                m.notificationInterval = m.top.myvideo.notificationInterval
              end if
              m.contentSession = m.LivePass.createSession(true, contentInfo, m.notificationInterval, m.top.myvideo, m.sessionOptions)
            end if
          end if
        end if
      else if msg.GetField() = "content" then
        'Create content session when content field is set on video node. (first event). After this, video play is called from application
          assetName = ""
          if assetName = "" and m.top.metadata.assetName <> invalid
            assetName = m.top.metadata.assetName
          end if
          if m.top.myvideo.content <> invalid and assetName = ""
            assetName = m.top.myvideo.content.title
          end if
          if assetName = ""
            assetName = "No assetName detected"
          end if
          contentInfo = ConvivaContentInfo(assetName, m.top.metadata.customMetadata)
          if m.top.metadata.streamUrl <> invalid or m.top.metadata.streamUrl = ""
            contentInfo.streamUrl = m.top.metadata.streamUrl
          else if m.top.myvideo.content <> invalid
            contentInfo.streamUrl = m.top.myvideo.content.url
          end if
          m.contentStreamUrl = contentInfo.streamUrl

          contentInfo.playerName = m.top.metadata.playerName
          contentInfo.isLive = m.top.metadata.isLive
          contentInfo.viewerId = m.top.metadata.viewerId
          contentInfo.contentLength = m.top.metadata.contentLength
          contentInfo.defaultReportingResource = m.top.metadata.defaultReportingResource
          contentInfo.encodedFramerate = m.top.metadata.encodedFramerate
          contentInfo.streamFormat = m.top.metadata.streamFormat
        if m.contentSession = invalid
          m.contentSession = m.LivePass.createSession(true, contentInfo, m.notificationInterval, m.top.myvideo, m.sessionOptions)
        else
          m.Livepass.updateContentMetadata(m.contentSession, contentInfo)
        end if
      else if msg.GetField() = "event"
        eventData = msg.GetData()
        if eventData.type = "ConvivaContentError"
          m.LivePass.reportError(m.contentSession, eventData.message, eventData.severity)
        else if eventData.type = "ConvivaContentEvent"
          m.LivePass.sendSessionEvent(m.contentSession, eventData.eventType, eventData.eventDetail)
        else if eventData.type = "ConvivaGlobalEvent"
          m.LivePass.sendEvent(eventData.eventType, eventData.eventDetail)
        else if eventData.type = "ConvivaContentPauseMonitor"
          m.LivePass.detachStreamer()
          m.LivePass.adStart()
        else if eventData.type = "ConvivaContentResumeMonitor"
          m.LivePass.adEnd()
          m.LivePass.attachStreamer()
        else if eventData.type = "ConvivaContentBitrate"
          if m.contentSession <> Invalid
            m.contentSession.externalBitrateReporting = true
            m.LivePass.setBitrateKbps(m.contentSession, eventData.bitrate)
          end if
        else if eventData.type = "ConvivaContentAverageBitrate"
          if m.contentSession <> Invalid
            m.LivePass.setAverageBitrateKbps(m.contentSession, eventData.avgbitrate)
          end if
        else if eventData.type = "ConvivaUpdateVideoNode"
          if eventData.videoNode <> invalid
            updateVideoNode(eventData.videoNode)
          end if
          m.LivePass.updateVideoNode(m.top.myvideo)
          m.LivePass.adEnd()
          m.LivePass.attachStreamer()
        else if eventData.type = "ConvivaContentSeekStart"
          if eventData.seekPos <> invalid
            seekToPos = eventData.seekPos
          else
            seekToPos = -1
          end if
          m.LivePass.setPlayerSeekStart(m.contentSession, seekToPos)
        else if eventData.type = "ConvivaContentSeekEnd"
          m.LivePass.setPlayerSeekEnd(m.contentSession)
        else if eventData.type = "ConvivaCleanupSession"
          if m.contentSession <> invalid
            if m.adSession <> invalid
              m.LivePass.cleanupSession(m.adSession)
            end if
            m.LivePass.cleanupSession(m.contentSession)
          end if

        else if eventData.type = "ConvivaUpdateContentMetadata"
          contentInfo = ConvivaContentInfo(eventData.assetName, eventData.customMetadata)
          contentInfo.streamUrl = eventData.streamUrl
          contentInfo.playerName = eventData.playerName
          contentInfo.viewerId = eventData.viewerId
          contentInfo.contentLength = eventData.contentLength
          contentInfo.isLive = eventData.isLive
          contentInfo.defaultReportingResource = eventData.defaultReportingResource
          contentInfo.encodedFramerate = eventData.encodedFramerate
          contentInfo.streamFormat = eventData.streamFormat

          ' Placing user reported metadata to m.top so that next time if video.content fields are changed, then metadata from older object is not written. Disney reported this issue
          m.top.metadata = eventData
          m.Livepass.updateContentMetadata(m.contentSession, contentInfo)
        else if eventData.type = "ConvivaUpdateAdMetadata"
          adInfo = ConvivaContentInfo(eventData.assetName, eventData.customMetadata)
          adInfo.streamUrl = eventData.streamUrl
          adInfo.playerName = eventData.playerName
          adInfo.viewerId = eventData.viewerId
          adInfo.contentLength = eventData.contentLength
          adInfo.isLive = eventData.isLive
          adInfo.defaultReportingResource = eventData.defaultReportingResource
          adInfo.encodedFramerate = eventData.encodedFramerate
          adInfo.streamFormat = eventData.streamFormat

          m.Livepass.updateContentMetadata(m.adSession, adInfo)
        else if eventData.type = "ConvivaCDNServerIP"
          if m.contentSession <> invalid
            m.contentSession.externalCdnServerIpReporting = true
            m.LivePass.setCDNServerIP(m.contentSession, eventData.cdnServerIPAddress)
          end if
        else if eventData.type = "ConvivaLog"
          if m.contentSession <> invalid and m.LivePass <> invalid
            m.LivePass.log(eventData.msg)
            end if
        else
          ' Method is common to all integrations using ConvivaClient APIs for ad insights integration'
          ' Present in ConvivaAIMonitor.brs'
          handleAdEvent(eventData)
        end if
      end if
    end if
  end while
end sub

' Utility method to initialize conviva on "RUN"ning of current task'
sub initConvivaCore(customerId as string, gatewayUrl as string, enableLogging as Boolean)
  cfg = {}
  cfg.gatewayUrl = gatewayUrl
  m.LivePass = ConvivaLivePassInitWithSettings(customerId, cfg)
  if m.LivePass <> invalid
    m.LivePass.toggleTraces(enableLogging)
    m.contentSession = invalid
    m.adSession = invalid
  else
    print "ConvivaLivePassInitWithSettings init has failed"
  end if
end sub
