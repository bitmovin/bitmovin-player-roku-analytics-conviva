sub init()
  m.playerConfig = getExamplePlayerConfig()

  ' Creates the ComponentLibrary (the BitmovinPlayerSDK in this case)
  m.bitmovinPlayerSDK = CreateObject("roSGNode", "ComponentLibrary")
  m.bitmovinPlayerSDK.id = "BitmovinPlayerSDK"
  ' NOTE: for dev purposes, a node server can be spun up that has the player library as a zip file
  m.bitmovinPlayerSDK.uri = "https://cdn.bitmovin.com/player/roku/1/bitmovinplayer.zip"

  ' Adding the ComponentLibrary node to the scene will start the download of the library
  m.top.appendChild(m.bitmovinPlayerSDK)
  m.bitmovinPlayerSDK.observeField("loadStatus", "onLoadStatusChanged")

  m.conviva = CreateObject("roSGNode", "ComponentLibrary")
  m.conviva.id = "conviva"
  m.conviva.uri = "http://192.168.1.48:8080/roku/player.zip"
  m.top.appendChild(m.conviva)
  m.conviva.observeField("loadStatus", "onLoadStatusChanged")
end sub

' The ComponentLibrary loadStatus field can equal "none", "ready", "loading" or "failed"
sub onLoadStatusChanged()
  print "LOAD STATUS FOR LIBRARY: "; m.bitmovinPlayerSDK.loadStatus
  if (m.bitmovinPlayerSDK.loadStatus = "ready" and m.conviva.loadStatus = "ready")
    ' Once the player library is loaded and ready, we can use it to reference the BitmovinPlayer component
    m.bitmovinPlayer = CreateObject("roSGNode", "BitmovinPlayerSDK:BitmovinPlayer")
    m.top.appendChild(m.bitmovinPlayer)
    m.BitmovinFunctions = m.bitmovinPlayer.BitmovinFunctions
    m.BitmovinFields = m.bitmovinPlayer.BitmovinFields
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.ERROR, "catchVideoError")
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.WARNING, "catchVideoWarning")
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.SEEK, "onSeek")
    m.bitmovinPlayer.ObserveField(m.BitmovinFields.SEEKED, "onSeeked")

'============================================================================================'
    m.convivaAnalytics = CreateObject("roSGNode", "conviva:ConvivaAnalytics")

    player = m.bitmovinPlayer
    customerKey = "250a04a88b97e5e54ff3edd2929b847e10c009c3"
    config = {
      debuggingEnabled : true
      gatewayUrl : "https://bitmovin-test.testonly.conviva.com"
    }

    m.convivaAnalytics.callFunc("setup", player, customerKey, config)
'============================================================================================'

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
