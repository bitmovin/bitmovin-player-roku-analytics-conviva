'*********************************************************************
'** (c) 2016 Roku, Inc.  All content herein is protected by U.S.
'** copyright and other applicable intellectual property laws and may
'** not be copied without the express permission of Roku, Inc., which
'** reserves all rights.  Reuse of any of this content for any purpose
'** without the permission of Roku, Inc. is strictly prohibited.
'*********************************************************************

function init()
    m.DEBUG = true

    ' Need to set to customer_key
    apiKey = "250a04a88b97e5e54ff3edd2929b847e10c009c3"
    cfg = {}
    cfg.gatewayUrl = "https://bitmovin-test.testonly.conviva.com"
    m.LivePass = ConvivaLivePassInitWithSettings(apiKey, cfg)
    ' m.LivePass = ConvivaLivePassInitWithSettings(apiKey)

    if m.LivePass <> invalid
        m.LivePass.toggleTraces(false)
    else
        if (m.DEBUG)
            print "ConvivaLivePassInitWithSettings init has failed"
        end if
    end if
    m.cSession = invalid
    m.adSession = invalid

    m.top.functionName = "startConvivaSession"
    m.top.id = "ConvivaTask"
end function

function startConvivaSession()
    port = CreateObject("roMessagePort")
    m.LivePass = ConvivaLivePassInstance ()

    if m.LivePass = invalid
        print "Error: LivePass instance creation has failed"
        return invalid
    end if

    video = m.top.video

    video.observeField("streamInfo", port)
    video.observeField("position", port)
    video.observeField("state", port)
    video.observeField("duration", port)
    video.observeField("streamingSegment", port)
    video.observeField("errorCode", port)
    video.observeField("errorMsg", port)
    video.observeField("downloadedSegment", port)

    m.top.observeField("convivaCustomEvent", port)

    while(true)
        msg = ConvivaWait(0, port, invalid)
        msgType = type(msg)
        if msgType = "roSGNodeEvent" and msg.getField() = "convivaCustomEvent"
            if m.DEBUG
                print "inside msg.getField() convivaCustomEvent";msg.GetData()
            end if
            if msg.GetData().type = "adStart" and m.cSession <> invalid
                m.LivePass.adStart()
            else if msg.GetData().type = "adEnd" and m.cSession <> invalid
                m.LivePass.adEnd()
            else if msg.GetData().type = "attachStreamer" and m.cSession <> invalid
                m.Livepass.attachStreamer()
            else if msg.GetData().type = "detachStreamer" and m.cSession <> invalid
                m.LivePass.detachStreamer()
            else if msg.GetData().type = "sendContentSessionEvent" and m.cSession <> invalid
                m.LivePass.sendSessionEvent(m.cSession, msg.GetData().eventName, msg.GetData().eventAttr)
            else if msg.GetData().type = "sendAdSessionEvent" and m.adSession <> invalid
                m.LivePass.sendSessionEvent(m.adSession, msg.GetData().eventName, msg.GetData().eventAttr)
            else if msg.GetData().type = "reportErrorContentSession" and m.cSession <> invalid
                if msg.GetData().errSeverity = true
                    errSeverity = m.LivePass.StreamerError.SEVERITY_FATAL
                else
                    errSeverity = m.LivePass.StreamerError.SEVERITY_WARNING
                end if
                m.LivePass.reportError(m.cSession, msg.GetData().errMessage, errSeverity)
            else if msg.GetData().type = "reportErrorAdSession" and m.adSession <> invalid
                if msg.GetData().errSeverity = true
                    errSeverity = m.LivePass.StreamerError.SEVERITY_FATAL
                else
                    errSeverity = m.LivePass.StreamerError.SEVERITY_WARNING
                end if
                m.LivePass.reportError(m.adSession, msg.GetData().errMessage, errSeverity)
            else if msg.GetData().type = "updateContentMetadata" and m.cSession <> invalid
                contentInfo = ConvivaContentInfo(msg.GetData().assetName, msg.GetData().tags)
                contentInfo.streamUrl = msg.GetData().streamUrl
                contentInfo.playerName = msg.GetData().playerName
                contentInfo.viewerId = msg.GetData().viewerId
                contentInfo.contentLength = msg.GetData().contentLength
                contentInfo.isLive = msg.GetData().isLive
                contentInfo.defaultReportingResource = msg.GetData().defaultReportingResource
                contentInfo.contentLength = msg.GetData().contentLength
                contentInfo.encodedFramerate = msg.GetData().encodedFramerate

                m.Livepass.updateContentMetadata(m.cSession, contentInfo)
            else if msg.GetData().type = "cleanupContentSession" and m.cSession <> invalid
                m.Livepass.cleanupSession(m.cSession)
                m.cSession = invalid
            else if msg.GetData().type = "cleanupAdSession" and m.adSession <> invalid
                m.Livepass.cleanupSession(m.adSession)
                m.adSession = invalid
            else if msg.GetData().type = "createContentSession" and m.cSession = invalid
                contentInfo = ConvivaContentInfo()
                if msg.GetData().contentInfo.assetName <> invalid
                    contentInfo.assetName = msg.GetData().contentInfo.assetName
                end if
                if msg.GetData().contentInfo.tags <> invalid
                    contentInfo.tags = msg.GetData().contentInfo.tags
                end if
                if msg.GetData().contentInfo.streamUrl <> invalid
                    contentInfo.streamUrl = msg.GetData().contentInfo.streamUrl
                end if
                if msg.GetData().contentInfo.playerName <> invalid
                    contentInfo.playerName = msg.GetData().contentInfo.playerName
                end if
                if msg.GetData().contentInfo.viewerId <> invalid
                    contentInfo.viewerId = msg.GetData().contentInfo.viewerId
                end if
                if msg.GetData().contentInfo.contentLength <> invalid
                    contentInfo.contentLength = msg.GetData().contentInfo.contentLength
                end if
                if msg.GetData().contentInfo.isLive <> invalid
                    contentInfo.isLive = msg.GetData().contentInfo.isLive
                end if
                if msg.GetData().contentInfo.defaultReportingResource <> invalid
                    contentInfo.defaultReportingResource = msg.GetData().contentInfo.defaultReportingResource
                end if
                if msg.GetData().contentInfo.encodedFramerate <> invalid
                    contentInfo.encodedFramerate = msg.GetData().contentInfo.encodedFramerate
                end if
                if msg.GetData().contentInfo.defaultReportingBitrateKbps <> invalid
                    contentInfo.defaultReportingBitrateKbps = msg.GetData().contentInfo.defaultReportingBitrateKbps
                end if
                if msg.GetData().contentInfo.streamFormat <> invalid
                    contentInfo.streamFormat = msg.GetData().contentInfo.streamFormat
                end if
                m.cSession = m.LivePass.createSession(msg.GetData().streamer, contentInfo, msg.GetData().notificationPeriod, video)
            else if msg.GetData().type = "createAdSession" and m.adSession = invalid
                contentInfo = ConvivaContentInfo()
                if msg.GetData().contentInfo.assetName <> invalid
                    contentInfo.assetName = msg.GetData().contentInfo.assetName
                end if
                adTags = {}
                adTags["c3.ad.technology"] = m.LivePass.AD_TECHNOLOGY.CLIENT_SIDE
                adTags["c3.ad.position"] = m.LivePass.AD_POSITION.MIDROLL
                adTags["c3.ad.servingType"] = m.LivePass.AD_SERVING_TYPE.INLINE
                adTags["c3.ad.type"] = m.LivePass.AD_TYPE.VPAID
                adTags["c3.ad.category"] = m.LivePass.AD_CATEGORY.LOCAL
                contentInfo.tags = adTags

                if msg.GetData().contentInfo.streamUrl <> invalid
                    contentInfo.streamUrl = msg.GetData().contentInfo.streamUrl
                end if
                if msg.GetData().contentInfo.playerName <> invalid
                    contentInfo.playerName = msg.GetData().contentInfo.playerName
                end if
                if msg.GetData().contentInfo.viewerId <> invalid
                    contentInfo.viewerId = msg.GetData().contentInfo.viewerId
                end if
                if msg.GetData().contentInfo.contentLength <> invalid
                    contentInfo.contentLength = msg.GetData().contentInfo.contentLength
                end if
                if msg.GetData().contentInfo.isLive <> invalid
                    contentInfo.isLive = msg.GetData().contentInfo.isLive
                end if
                if msg.GetData().contentInfo.defaultReportingResource <> invalid
                    contentInfo.defaultReportingResource = msg.GetData().contentInfo.defaultReportingResource
                end if
                if msg.GetData().contentInfo.encodedFramerate <> invalid
                    contentInfo.encodedFramerate = msg.GetData().contentInfo.encodedFramerate
                end if
                if msg.GetData().contentInfo.defaultReportingBitrateKbps <> invalid
                    contentInfo.defaultReportingBitrateKbps = msg.GetData().contentInfo.defaultReportingBitrateKbps
                end if
                if msg.GetData().contentInfo.streamFormat <> invalid
                    contentInfo.streamFormat = msg.GetData().contentInfo.streamFormat
                end if
                m.adSession = m.LivePass.createAdSession(m.cSession, msg.GetData().streamer, contentInfo, msg.GetData().notificationPeriod, video)
            else if msg.GetData().type = "setPlayerSeekStart" and m.cSession <> invalid
                m.LivePass.setPlayerSeekStart(m.cSession, msg.GetData().seekToInMs)
            else if msg.GetData().type = "setPlayerSeekEnd" and m.cSession <> invalid
                m.LivePass.setPlayerSeekEnd(m.cSession)
            else if msg.GetData().type = "updateVideoNode" and m.cSession <> invalid
                m.Livepass.updateVideoNode(video)
            else if msg.GetData().type = "setContentSessionBitrateKbps" and m.cSession <> invalid
                m.Livepass.setBitrateKbps(m.cSession, msg.GetData().bitrateKbps)
            else if msg.GetData().type = "setAdSessionBitrateKbps" and m.adSession <> invalid
                m.Livepass.setBitrateKbps(m.adSession, msg.GetData().bitrateKbps)
            else if msg.GetData().type = "cleanupConviva" and m.cSession <> invalid
                m.Livepass.cleanup()
                exit while
            end if
        end if
    end while
    m.Livepass = invalid
    video = invalid
    m.top.video = invalid
end function
