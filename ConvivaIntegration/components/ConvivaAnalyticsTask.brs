sub init()
  m.top.functionName = "monitorVideo"
  m.cSession = invalid
  m.DEBUG = false
end sub

sub monitorVideo()
  if m.top.config.debuggingEnabled = true then m.DEBUG = true
  apiKey = m.top.customerKey
  if m.top.config.gatewayUrl <> invalid
    cfg = {}
    cfg.gatewayUrl = m.top.config.gatewayUrl
    m.LivePass = ConvivaLivePassInitWithSettings(apiKey, cfg)
  else
    m.LivePass = ConvivaLivePassInitWithSettings(apiKey)
  end if

  firstTimePlaying = true
  player = m.top.player
  port = CreateObject("roMessagePort")
  player.observeField("state", port)
  m.LivePass = ConvivaLivePassInstance()

  while true
    print "in while true"
    msg = ConvivaWait(0, port, invalid) ' conviva wait eats thread
    print "message in while true: "; msg
    if type(msg) = "roSgNodeEvent"
      data = msg.GetData()
      if m.DEBUG then print "New Data recieved: "; data
      if data = "playing" and m.firstTimePlaying ' TODO: replace workaround with proper solution
        contentInfo = ConvivaContentInfo()
        print "ContentInfo: "; contentInfo
        m.cSession = m.LivePass.createSession(true, contentInfo, 1.0, player)


        m.firstTimePlaying = false
      else if data = "playing"

      else if data = "paused"

      else if data = "stalling"

      else if data = "finished" or data = "error"

      else

      end if
    end if
  end while
end sub
