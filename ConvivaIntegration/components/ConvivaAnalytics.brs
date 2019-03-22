sub init()
  m.convivaTask = createObject("roSGNode", "ConvivaAnalyticsTask")
end sub

sub setup(player, customerKey, config)
  m.convivaTask.player = player
  m.convivaTask.customerKey = customerKey
  m.convivaTask.config = config
  m.convivaTask.control = "RUN"
end sub
