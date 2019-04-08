sub init()
end sub

sub setup(player, customerKey, config)
  video = player.findNode("MainVideo")
  if video.content <> invalid
    print "[ConvivaAnalytics] Bitmovin Conviva integration must be instantiated before calling player.load()"
    return
  end if

  m.convivaTask = createObject("roSGNode", "ConvivaAnalyticsTask")
  m.convivaTask.player = player
  m.convivaTask.customerKey = customerKey
  m.convivaTask.config = config
  m.convivaTask.control = "RUN"
end sub

sub updateContentMetadata(contentMetadataOverrides)
  m.convivaTask.invoke = {
    method: "updateContentMetadata",
    contentMetadata: contentMetadataOverrides
  }
end sub

' Sends a custom deficiency event during playback to Conviva's Player Insight. If no session is active it will NOT
' create one.
'
' @param {String} message - Message which will be send to conviva
' @param {Boolean} isFatal - Flag if the error is fatal or just a warning
' @param {Boolean} endSession - flag if session should be closed after reporting the deficiency (Default: true)
sub reportPlaybackDeficiency(message, isFatal, endSession = true)
  m.convivaTask.invoke = {
    method: "reportPlaybackDeficiency",
    message: message,
    isFatal: isFatal,
    endSession: endSession
  }
end sub
