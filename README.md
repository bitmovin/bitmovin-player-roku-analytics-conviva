# Bitmovin Player Conviva Analytics Integration

## Limitations
Currently we don't support ad tracking.

## Compatibility
**This version of the Conviva Analytics Integration works only with Bitmovin Player Version >= 1.7.x.
The recommended and tested version of the Conviva SDK is 2.151.0.36990.**

## Getting Started
1. Clone Git repository

## Running the example

1. Run `npm i` to install dependencies
2. Fetch conviva SDK
  - Download conviva SDK source file
  - Rename to `Conviva_Roku.brs`
  - Put it into `./ConvivaIntegration/source/conviva`
3. Ensure that you are in the same network as the roku device
4. Run `npm run serve:example`
  _(This will copy all needed files from ./ConvivaIntegration to the ./demo folder)_
5. Enter your Conviva customer key and gateway URL in `demo/PlayerExample.brs`
6. Enter your Bitmovin player ID in `demo/manifest`
7. Zip and deploy the demo to the roku device

## Usage

### Use with Source Code

1. Fetch conviva SDK
  - Download conviva SDK source file
  - Rename to `Conviva_Roku.brs`
  - Create a folder in your source folder called `conviva`
  - Put the `Conviva_Roku.brs` into the newly created `./source/conviva` folder. _If you want to create a different folder structure you need to change the import of the `ConvivaSDK` within the `ConvivaAnalyticsTask.xml`_
2. Copy following files to your components folder:
  - `./ConvivaIntegration/components/ConvivaAnalytics.brs`
  - `./ConvivaIntegration/components/ConvivaAnalytics.xml`
  - `./ConvivaIntegration/components/ConvivaAnalyticsTask.brs`
  - `./ConvivaIntegration/components/ConvivaAnalyticsTask.xml`
  - `./ConvivaIntegration/components/ContentMetadataBuilder.brs`
  - `./ConvivaIntegration/components/ContentMetadataBuilder.xml`
  - `./ConvivaIntegration/components/helper`
3. Create a instance of `ConvivaAnalytics`
  ```Brightscript
  m.convivaAnalytics = CreateObject("roSGNode", "ConvivaAnalytics")
  ```

### Use as Component Library

1. Fetch conviva SDK
  - Download conviva SDK source file
  - Rename to `Conviva_Roku.brs`
  - Put it into `./ConvivaIntegration/source/conviva`
2. run `npm install && npm run build:component`
3. Include the created ZIP from the `./dist` folder into your channel as a component library
  ```Brightscript
  m.conviva = CreateObject("roSGNode", "ComponentLibrary")
  m.conviva.id = "conviva"
  m.conviva.uri = "http://PATH_TO_YOUR_ZIP.zip"
  m.top.appendChild(m.conviva)
  m.conviva.observeField("loadStatus", "YOUR_CALLBACK") ' Ensure the library is loaded before using it
  ```

4. Create an instance of `ConvivaAnalytics` within the callback
  ```Brightscript
  m.convivaAnalytics = CreateObject("roSGNode", "bitmovinPlayerIntegrationConviva:ConvivaAnalytics")
  ```

### Setup

1. Setting up the instance of `ConvivaAnalytics`

  _Ensure that the bitmovinPlayer exists here as well_
  ```Brightscript
  customerKey = "YOUR_CUSTOMER_KEY"
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

If you want to track custom VPF (Video Playback Failures) events when no actual player error happens (e.g.
endless stalling due to network condition) you can use following API to track those deficiencies:

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
    "CustomKey": "CustomValue"
  }
}
m.convivaAnalytics.callFunc("updateContentMetadata", contentMetadataOverrides)
```

#### End a Session

If you want to end a session manually you can do so by adding the following:

```Brightscript
m.convivaAnalytics.callFunc("endSession")
```
