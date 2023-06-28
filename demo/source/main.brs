sub main()
  print "################" ' eslint-disable-line roku/no-print
  print "Start of Channel" ' eslint-disable-line roku/no-print
  print "################" ' eslint-disable-line roku/no-print

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
    if type(msg) = "roSGScreenEvent" then
        if msg.isScreenClosed() then exit while
    end if
  end while
end sub
