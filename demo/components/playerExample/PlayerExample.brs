sub init()
  m.playerConfig = getExamplePlayerConfig()

  ' Creates the ComponentLibrary (the BitmovinPlayerSDK in this case)
  m.bitmovinPlayerSDK = CreateObject("roSGNode", "ComponentLibrary")
  m.bitmovinPlayerSDK.id = "BitmovinPlayerSDK"
  m.bitmovinPlayerSDK.uri = "https://cdn.bitmovin.com/player/roku/1.4.0-b.2/bitmovinplayer.zip"

  ' Adding the ComponentLibrary node to the scene will start the download of the library
  m.top.appendChild(m.bitmovinPlayerSDK)
  m.bitmovinPlayerSDK.observeField("loadStatus", "onLoadStatusChanged")

  ' Do the same for the conviva integration
  m.conviva = CreateObject("roSGNode", "ComponentLibrary")
  m.conviva.id = "conviva"
  m.conviva.uri = "http://YOUR_IP:8088/bitmovin-player-conviva-analytics.zip"
  m.top.appendChild(m.conviva)
  m.conviva.observeField("loadStatus", "onLoadStatusChanged")
end sub

' The ComponentLibrary loadStatus field can equal "none", "ready", "loading" or "failed"
sub onLoadStatusChanged()
  print "LOAD STATUS FOR LIBRARY: "; m.bitmovinPlayerSDK.loadStatus
  if (m.bitmovinPlayerSDK.loadStatus = "ready" and m.conviva.loadStatus = "ready")
    ' Once the librarird are loaded and ready, we can use them to reference the BitmovinPlayer and the ConvivaAnalytics components
    m.bitmovinPlayer = CreateObject("roSGNode", "BitmovinPlayerSDK:BitmovinPlayer")
    m.top.appendChild(m.bitmovinPlayer)
    m.BitmovinFunctions = m.bitmovinPlayer.BitmovinFunctions
    m.BitmovinFields = m.bitmovinPlayer.BitmovinFields
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.ERROR, "catchVideoError")
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.WARNING, "catchVideoWarning")
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.SEEK, "onSeek")
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.SEEKED, "onSeeked")

    m.convivaAnalytics = CreateObject("roSGNode", "conviva:ConvivaAnalytics")
    player = m.bitmovinPlayer
    customerKey = "250a04a88b97e5e54ff3edd2929b847e10c009c3"
    config = {
      debuggingEnabled : true
      gatewayUrl : "https://bitmovin-test.testonly.conviva.com"
    }
    m.convivaAnalytics.callFunc("setup", player, customerKey, config)
    contentMetadataOverrides = {
      playerName: "Conviva Integration Test Channel",
      viewerId: "MyAwesomeViewerId",
      tags: {
        CustomKey: "CustomValue"
      }
    }
    m.convivaAnalytics.callFunc("updateContentMetadata", contentMetadataOverrides)

    m.bitmovinPlayer.callFunc(m.BitmovinFunctions.SETUP, m.playerConfig)
  end if
end sub

sub catchVideoError()
  print "ERROR: "; m.bitmovinPlayer.error.code.toStr() + ": " + m.bitmovinPlayer.error.message
end sub

sub catchVideoWarning()
  print "WARNING: "; m.bitmovinPlayer.warning.code.toStr() + ": " + m.bitmovinPlayer.warning.message
end sub

sub onSeek()
  print "SEEKING"
end sub

sub onSeeked()
  print "SEEKED: "; m.bitmovinPlayer.seeked
end sub
