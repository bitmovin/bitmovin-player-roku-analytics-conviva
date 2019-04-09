sub init()
  m.InvokeMethods = {
    UPDATE_CONTENT_METADATA: "updateContentMetadata",
    END_SESSION: "endSEssion",
    REPORT_PLAYBACK_DEFICIENCY: "reportPlaybackDeficiency"
  }
end sub

sub setup(player, customerKey, convivaConfig)
  playerConfig = player.callFunc("getConfig")
  if playerConfig <> invalid and playerConfig.source <> invalid
    print "[ConvivaAnalytics] Bitmovin Conviva integration must be instantiated before calling player.load() or player.setup()"
    return
  end if

  m.convivaTask = createObject("roSGNode", "ConvivaAnalyticsTask")
  m.convivaTask.player = player
  m.convivaTask.customerKey = customerKey
  m.convivaTask.config = convivaConfig
  m.convivaTask.control = "RUN"
end sub

sub updateContentMetadata(contentMetadataOverrides)
  m.convivaTask.invoke = {
    method: m.InvokeMethods.UPDATE_CONTENT_METADATA,
    contentMetadata: contentMetadataOverrides
  }
end sub

' Ends the current conviva tracking session.
' Results in a no-op if there is no active session.
'
' Warning: The integration can only be validated without external session management. So when using this method we can
' no longer ensure that the session is managed at the correct time.
sub endSession()
  m.convivaTask.invoke = {
    method: m.InvokeMethods.END_SESSION
  }
end sub

' Sends a custom deficiency event during playback to Conviva's Player Insight. If no session is active it will NOT
' create one.
'
' @param {String} message - Message which will be send to conviva
' @param {Boolean} isFatal - Flag if the error is fatal or just a warning
' @param {Boolean} [endSession=true] - Flag if the session should be closed after reporting the deficiency
sub reportPlaybackDeficiency(message, isFatal, endSession = true)
  m.convivaTask.invoke = {
    method: m.InvokeMethods.REPORT_PLAYBACK_DEFICIENCY,
    message: message,
    isFatal: isFatal,
    endSession: endSession
  }
end sub
