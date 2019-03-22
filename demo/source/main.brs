sub main()
  print "################"
  print "Start of Channel"
  print "################"

  'NOTE: useful when testing DRM
  'di = CreateObject("roDeviceInfo")
  'print di.GetDrmInfoEx()

  port = CreateObject("roMessagePort")
  screen = CreateObject("roSGScreen")
  screen.setMessagePort(port)
  ' NOTE: Insert example scene name here for testing
  ' EXAMPLES: PlayerExample
  scene = screen.CreateScene("PlayerExample")
  screen.show()

  while true
    msg = wait(0, port)
    if type(msg) = "roSGScreenEvent"
        if msg.isScreenClosed() then exit while
    end if
  end while
end sub
