function getExamplePlayerConfig()
  return {
    playback: {
      autoplay: false,
      muted: false
    },
    adaptation: {
      preload: false
    },
    source: {
      hls: "https://bitmovin-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8",
      title: "Test video",
      assetType: "vod"
    }
  }
end function
