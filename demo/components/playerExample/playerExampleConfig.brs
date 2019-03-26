function getExamplePlayerConfig()
  return {
    playback: {
      autoplay: true,
      muted: true
    },
    adaptation: {
      preload: false
    },
    source: {
      hls: "https://demo-hls5-live.zahs.tv/hd/master.m3u8?timeshift=300",
      title: "Test video"
      assetType = "live"
    }
  }
end function
