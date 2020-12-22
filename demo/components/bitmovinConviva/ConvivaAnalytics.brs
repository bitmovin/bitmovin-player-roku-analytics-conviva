sub init()
    m.InvokeMethods = {
        INITIALIZE_CONVIVA: "initializeConviva",
        UPDATE_CONTENT_METADATA: "updateContentMetadata",
        MONITOR_VIDEO: "monitorVideo",
        END_SESSION: "endSession",
        REPORT_PLAYBACK_DEFICIENCY: "reportPlaybackDeficiency",
        SEND_CUSTOM_APPLICATION_EVENT: "sendCustomApplicationEvent",
        SEND_CUSTOM_PLAYBACK_EVENT: "sendCustomPlaybackEvent"
    }

    m.top.adTrackingModes = {
        BASIC: 0,
        AD_BREAK: 1,
        AD_EXPERIENCE: 2
    }
end sub

sub setup(player, customerKey, convivaConfig)
    playerConfig = player.callFunc("getConfig")
    if playerConfig <> invalid and playerConfig.source <> invalid
        ? "[ConvivaAnalytics] Bitmovin Conviva integration must be instantiated before calling player.load() or player.setup()"
        return
    end if

    m.convivaTask = CreateObject("roSGNode", "ConvivaAnalyticsTask")
    m.convivaTask.player = player
    m.convivaTask.customerKey = customerKey
    if convivaConfig.adTrackingMode = invalid then convivaConfig.adTrackingMode = m.top.adTrackingModes.BASIC
    m.convivaTask.config = convivaConfig

    m.convivaTask.adTrackingModes = m.top.adTrackingModes
    m.convivaTask.callFunc(m.InvokeMethods.INITIALIZE_CONVIVA)
end sub

sub updateContentMetadata(contentMetadataOverrides)
    m.convivaTask.callFunc(m.InvokeMethods.UPDATE_CONTENT_METADATA, contentMetadataOverrides)
end sub

sub monitorVideo(contentMetadataOverrides)
    m.convivaTask.callFunc(m.InvokeMethods.MONITOR_VIDEO, contentMetadataOverrides)
end sub

' Sends a custom application-level event to Conviva's Player Insight. An application-level event can always
' be sent and is not tied to a specific video.
' @param {String} name - Arbitrary event name
' @param {Object} attributes - A string-to-string dictionary object with arbitrary attribute keys and values
sub sendCustomApplicationEvent(name, attributes)
    m.convivaTask.callFunc(m.InvokeMethods.SEND_CUSTOM_APPLICATION_EVENT, name, attributes)
end sub

' Sends a custom playback-level event to Conviva's Player Insight. A playback-level event can only be sent
' during an active video session.
' @param {String} name - Arbitrary event name
' @param {Object} attributes - A string-to-string dictionary object with arbitrary attribute keys and values
sub sendCustomPlaybackEvent(name, attributes)
    m.convivaTask.callFunc(m.InvokeMethods.SEND_CUSTOM_PLAYBACK_EVENT, name, attributes)
end sub

' Ends the current conviva tracking session.
' Results in a no-op if there is no active session.

' Warning: The integration can only be validated without external session management. So when using this method we can
' no longer ensure that the session is managed at the correct time.
sub endSession()
    m.convivaTask.callFunc(m.InvokeMethods.END_SESSION)
end sub

' Sends a custom deficiency event during playback to Conviva's Player Insight. If no session is active it will NOT
' create one.

' @param {String} message - Message which will be send to conviva
' @param {Boolean} isFatal - Flag if the error is fatal or just a warning
' @param {Boolean} [endSession=true] - Flag if the session should be closed after reporting the deficiency
sub reportPlaybackDeficiency(message, isFatal, endSession = true)
    m.convivaTask.callFunc(m.InvokeMethods.REPORT_PLAYBACK_DEFICIENCY, message, isFatal, endSession)
end sub

