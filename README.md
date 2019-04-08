# Bitmovin Player Conviva Analytics Integration

## Getting Started

1. Clone Git repository
2. Create ZIP including all files in `ConvivaIntegration` folder
3. Include the created zip in your project

## Usage

1. Include the created ZIP into your channel
  ```Brightscript
  m.conviva = CreateObject("roSGNode", "ComponentLibrary")
  m.conviva.id = "conviva"
  m.conviva.uri = "http://PATH_TO_YOUR_ZIP.zip"
  m.top.appendChild(m.conviva)
  m.conviva.observeField("loadStatus", "YOUR_CALLBACK") ' Ensure the library is loaded
  ```

2. Create a instance of `ConvivaAnalytics` within the callback

  _Ensure that the bitmovinPlayer exists here as well_
  ```Brightscript
  m.convivaAnalytics = CreateObject("roSGNode", "conviva:ConvivaAnalytics") 'A ConvivaAnalytics instance is always tied to one player instance
  customerKey = "YOUR_CUSTOMER_KEX"
  config = {
    debuggingEnabled : true
    gatewayUrl : "YOUR_GATEWAY_URL" ' optional and only for testing
  }
  m.convivaAnalytics.callFunc("setup", m.bitmovinPlayer, customerKey, config)

  ' Initialize ConvivaAnalytics before calling setup or load on the bitmovinPlayer
  m.bitmovinPlayer.callFunc(m.BitmovinFunctions.SETUP, m.playerConfig)
  ```

### Advanced Usage

#### Custom Deficiency Reporting (VPF)

If you would like to track custom VPF (Video Playback Failures) events when no actual player error happens (e.g.
endless stalling due to network condition) you can use following API to track those deficiencies.

```Brightscript
m.convivaAnalytics.callFunc("reportPlaybackDeficiency", "MY_ERROR_MESSAGE", true, true)
```

_See [ConvivaAnalytics.brs](./ConvivaIntegration/components/ConvivaAnalytics.brs) for more details about the parameters._

#### Custom Events

If you want to track custom events you can do so by adding the following:

For an event not bound to a session, use:
```Brightscript
m.convivaAnalytics.callFunc("sendCustomApplicationEvent", "MY_EVENT_NAME", {
  eventAttributeKey: "eventAttributeValue"
})
```

For an event bound to a session, use:
```Brightscript
m.convivaAnalytics.callFunc("sendCustomPlaybackEvent", "MY_EVENT_NAME", {
  eventAttributeKey: "eventAttributeValue"
})
```

_See [ConvivaAnalytics.brs](./ConvivaIntegration/components/ConvivaAnalytics.brs) for more details._

#### Content Metadata Handling

If you want to override some content metadata attributes you can do so by adding the following:

```Brightscript
contentMetadataOverrides = {
  playerName: "Conviva Integration Test Channel",
  viewerId: "MyAwesomeViewerId",
  tags: {
    CustomKey: "CustomValue"
  }
}
m.convivaAnalytics.callFunc("updateContentMetadata", contentMetadataOverrides)
```

#### End a Session

If you want to end a session manually you can do so by adding the following:

```Brightscript
m.convivaAnalytics.callFunc("endSession")
```
