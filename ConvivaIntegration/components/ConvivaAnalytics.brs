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


' Ends the current conviva tracking session.
' Results in a no-opt if there is no active session.
'
' Warning: The integration can only be validated without external session managing. So when using this method we can
' no longer ensure that the session is managed at the correct time.
sub endSession()
  m.convivaTask.invoke = {
    method: "endSession"
  }
end sub
