sub init()
    m.conviva = invalid
    m.cSession = false
    m.DEBUG = false
    m.video = invalid
    m.PodIndex = 0
    m.adTracking = invalid
    m.adTrackingMode = 0

    m.contentMetadataBuilder = CreateObject("roSGNode", "ContentMetadataBuilder")

end sub

sub initializeConviva()
    debugLog("[ConvivaAnalytics] setting up")
    m.video = m.top.player.findNode("MainVideo")

    m.DEBUG = m.top.config.debuggingEnabled

    apiKey = m.top.customerKey
    settings = {}
    settings.customerKey = apiKey

    if m.top.config.gatewayUrl <> invalid
        settings.gatewayUrl = m.top.config.gatewayUrl
    end if
    m.conviva = ConvivaClient(settings)
    m.adTrackingMode = m.top.config.adTrackingMode
    if m.adTrackingMode > m.top.adTrackingModes.BASIC
        m.adTracking = initAdTracking(m.top.player, m.conviva, m.video)
    end if
    registerEvents()
end sub

sub sendCustomApplicationEvent(eventName, attributes)
    m.conviva.reportAppEvent(m.video, eventName, attributes)
end sub

sub sendCustomPlaybackEvent(eventName, attributes)
    if not isSessionActive()
        debugLog("Cannot send playback event, no active monitoring session")
        return
    end if

    m.conviva.reportContentPlayerEvent(m.video, eventName, attributes)
end sub

sub updateContentMetadata(metadataOverrides)
    m.contentMetadataBuilder.callFunc("setOverrides", metadataOverrides)
    if isSessionActive()
        buildContentMetadata()
        updateSession()
    end if
end sub

sub monitorVideo(metadataOverrides)
    if isSessionActive()
        ' Ending Session must be called earlier as possible than CreateConvivaSession because it takes time to clean up session
        ' Can't call createConvivaSession right after endSession()
        endSession()
    end if
    m.contentMetadataBuilder.callFunc("setOverrides", metadataOverrides)
end sub

sub onStateChanged(state)
    state = m.top.player.playerState
    debugLog("[ConvivaAnalytics] state changed: " + state)
    if state = "finished"
        onPlaybackFinished()
    else if state = "stopped"
        endSession()
    end if
    ' Other states are handled by conviva
end sub

sub onPlaybackFinished()
    endSession()
end sub

sub onPlay()
    debugLog("[Player Event] onPlay")
end sub

sub onPlaying()
    debugLog("[Player Event] onPlaying")
    m.contentMetadataBuilder.callFunc("setPlaybackStarted", true)
end sub

sub onSeek()
    debugLog("[Player Event] onSeek")

    m.conviva.reportSeekStarted(m.video, - 1)
end sub

sub onSourceLoaded()
    debugLog("[Player Event] onSourceLoaded!")
    ' createConvivaSession early as possible, can't be called in onPlay
    createConvivaSession()
end sub

sub onSourceUnloaded()
    debugLog("[Player Event] onSourceUnloaded")
end sub

sub onVideoError()
    if isSessionActive()
        reportPlaybackDeficiency(m.top.player.error.message, true, true) ' close session on video error
    end if
end sub

function onAdBreakStarted()
    if m.adTrackingMode > m.top.adTrackingModes.BASIC then m.adTracking.onAdBreakStarted()
end function

function onAdBreakFinished()
    if m.adTrackingMode > m.top.adTrackingModes.BASIC then m.adTracking.onAdBreakFinished()
end function

sub onAdError()
    m.conviva.reportAdError(m.video, "adError")
end sub

sub onAdSkipped()
    m.conviva.reportAdSkipped(m.video, invalid)
end sub

sub createConvivaSession()
    m.video = m.top.player.findNode("MainVideo") ' Get latest video node
    buildContentMetadata()

    m.conviva.monitorVideoNode(m.video, m.contentMetadataBuilder.callFunc("build"))
    m.cSession = true
    m.PodIndex = 0
    if m.adTracking <> invalid then m.adTracking.updateSession(m.video)
    debugLog("[ConvivaAnalytics] start session")
end sub

sub endSession()
    debugLog("[ConvivaAnalytics] closing session")
    m.conviva.endMonitoring(m.video)
    m.cSession = false
    m.contentMetadataBuilder.callFunc("reset")
end sub

sub reportPlaybackDeficiency(message, isFatal, closeSession = true)
    if not isSessionActive() then return
    debugLog("[ConvivaAnalytics] reporting deficiency")

    m.conviva.reportContentError(m.video, message, isFatal)

    if closeSession
        endSession()
    end if
end sub

function isSessionActive()
    return m.cSession
end function

sub buildContentMetadata()
    m.contentMetadataBuilder.callFunc("setDuration", m.video.duration)
    m.contentMetadataBuilder.callFunc("setStreamType", m.top.player.callFunc("isLive"))

    internalCustomTags = {
        "integrationVersion": "1.0.0"
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
    m.conviva.setOrUpdateContentInfo(m.video, m.contentMetadataBuilder.callFunc("build"))
end sub

sub registerEvents()
    registerPlayerEvents()
    registerAdEvents()
end sub

sub registerPlayerEvents()
    m.top.player.observeField(m.top.player.BitmovinFields.SEEK, "onSeek")
    m.top.player.observeField(m.top.player.BitmovinFields.PLAY, "onPlay")
    m.top.player.observeField(m.top.player.BitmovinFields.SOURCE_LOADED, "onSourceLoaded")
    m.top.player.observeField(m.top.player.BitmovinFields.SOURCE_UNLOADED, "onSourceUnloaded")
    m.top.player.observeField(m.top.player.BitmovinFields.PLAYER_STATE, "onStateChanged")
    m.top.player.observeField(m.top.player.BitmovinFields.PLAYER_STATE, "onStateChanged")
    m.top.player.ObserveField(m.top.player.BitmovinFields.ERROR, "onVideoError")

    ' In case of autoplay we miss the inital play callback.
    ' This does not affect VST.
    if m.top.player[m.top.player.BitmovinFields.PLAY] = true
        onPlay()
    end if
end sub

sub registerAdEvents()
    m.top.player.observeField("adBreakStarted", "onAdBreakStarted")
    m.top.player.observeField("adBreakFinished", "onAdBreakFinished")
    m.top.player.observeField("adError", "onAdError")
    m.top.player.observeField("adSkipped", "onAdSkipped")
end sub

sub debugLog(message as String)
    if m.DEBUG then ? message
end sub

function getAd(mediaId)
    adBreaks = m.top.player.callFunc(m.top.player.BitmovinFunctions.AD_LIST)
    for each adBreak in adBreaks
        for each ad in adBreak.ads
            if ad.id = mediaId then return ad
        end for
    end for

    return invalid
end function
