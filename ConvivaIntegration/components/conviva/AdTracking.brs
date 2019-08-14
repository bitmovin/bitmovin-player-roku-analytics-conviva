function initAdTracking(player, livePass, session = invalid)
  this = {}

  this["_player"] = player
  this["_livePass"] = livePass
  this["_podIndex"] = 0
  this["_session"] = session

  this["onAdBreakStarted"] = sub()
    adBreak = m._player.callFunc(m._player.BitmovinFunctions.AD_LIST)[m._podIndex]
    duration = 0

    for each ad in adBreak.ads
      duration += ad.duration
    end for

    if adBreak.scheduleTime = 0
      m.adType = "Pre-roll"
    else if ((adBreak.scheduleTime + duration) >= m.video.duration)
      m.adType = "Post-roll"
    else
      m.adType = "Mid-roll"
    end if

    m._podIndex++

    podInfo = {
      "podDuration": StrI(duration),
      "podPosition": m.adType,
      "podIndex": StrI(m._podIndex),
      "absoluteIndex": "1"
    }
    print "sending pod info now"; podInfo
    print "to session "; m._session
    m._livePass.sendSessionEvent(m._session, "Conviva.PodStart", podInfo)
  end sub

  this["onAdBreakFinished"] = sub()
    podInfo = {
      "podPosition": m.adType,
      "podIndex": StrI(m._podIndex),
      "absoluteIndex": "1"
    }

    print "sending pod end info now"; podInfo
    m._livePass.sendSessionEvent(m._session, "Conviva.PodEnd", podInfo)
  end sub

  this["updateSession"] = sub(session)
    m._session = session
  end sub

  return this
end function
