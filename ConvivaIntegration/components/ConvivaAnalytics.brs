sub init()
  m.InvokeMethods = {
    UPDATE_CONTENT_METADATA: "updateContentMetadata"
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
