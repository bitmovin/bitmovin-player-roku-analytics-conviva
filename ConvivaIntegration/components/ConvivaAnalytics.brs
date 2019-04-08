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

' Sends a custom application-level event to Conviva's Player Insight. An application-level event can always
' be sent and is not tied to a specific video.
' @param {String} name - arbitrary event name
' @param {Object} attributes - a string-to-string dictionary object with arbitrary attribute keys and values
sub sendCustomApplicationEvent(name, attributes)
  m.convivaTask.invoke = {
    method: "sendCustomApplicationEvent",
    eventName: name,
    attributes: attributes
  }
end sub

' Sends a custom playback-level event to Conviva's Player Insight. A playback-level event can only be sent
' during an active video session.
' @param {String} name - arbitrary event name
' @param {Object} attributes - a string-to-string dictionary object with arbitrary attribute keys and values
sub sendCustomPlaybackEvent(name, attributes)
  m.convivaTask.invoke = {
    method: "sendCustomPlaybackEvent",
    eventName: name,
    attributes: attributes
  }
end sub
