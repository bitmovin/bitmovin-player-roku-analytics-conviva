sub init()
  m.playerConfig = getExamplePlayerConfig()

  ' Creates the ComponentLibrary (the BitmovinPlayerSDK in this case)
  m.bitmovinPlayerSDK = CreateObject("roSGNode", "ComponentLibrary")
  m.bitmovinPlayerSDK.id = "BitmovinPlayerSDK"
  m.bitmovinPlayerSDK.uri = "https://cdn.bitmovin.com/player/roku/1.4.0-b.2/bitmovinplayer.zip"

  ' Adding the ComponentLibrary node to the scene will start the download of the library
  m.top.appendChild(m.bitmovinPlayerSDK)
  m.bitmovinPlayerSDK.observeField("loadStatus", "onLoadStatusChanged")
end sub

' The ComponentLibrary loadStatus field can equal "none", "ready", "loading" or "failed"
sub onLoadStatusChanged()
  print "LOAD STATUS FOR BITMOVINPLAYER LIBRARY: "; m.bitmovinPlayerSDK.loadStatus

  if (m.bitmovinPlayerSDK.loadStatus = "ready")
    ' Once the library is loaded and ready, we can use it to reference the BitmovinPlayer
    m.bitmovinPlayer = CreateObject("roSGNode", "BitmovinPlayerSDK:BitmovinPlayer")
    m.top.appendChild(m.bitmovinPlayer)
    m.BitmovinFunctions = m.bitmovinPlayer.BitmovinFunctions
    m.BitmovinFields = m.bitmovinPlayer.BitmovinFields
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.ERROR, "catchVideoError")
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.WARNING, "catchVideoWarning")
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.SEEK, "onSeek")
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.SEEKED, "onSeeked")

    m.convivaAnalytics = CreateObject("roSGNode", "ConvivaAnalytics")
    player = m.bitmovinPlayer
    customerKey = "CUSTOMER_KEY"
    config = {
      debuggingEnabled : true
      gatewayUrl : "https://youraccount-test.testonly.conviva.com", ' TOUCHSTONE_SERVICE_URL for testing
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
