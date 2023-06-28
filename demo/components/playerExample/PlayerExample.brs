sub init()
    m.playerConfig = getExamplePlayerConfig()

    ' Creates the ComponentLibrary (the BitmovinPlayerSDK in this case)
    m.bitmovinPlayerSDK = CreateObject("roSGNode", "ComponentLibrary")
    m.bitmovinPlayerSDK.id = "BitmovinPlayerSDK"
    m.bitmovinPlayerSDK.uri = "https://cdn.bitmovin.com/player/roku/1.7.0-b.1/bitmovinplayer.zip"

    ' Adding the ComponentLibrary node to the scene will start the download of the library
    m.top.appendChild(m.bitmovinPlayerSDK)
    m.bitmovinPlayerSDK.observeField("loadStatus", "onLoadStatusChanged")
end sub

' The ComponentLibrary loadStatus field can equal "none", "ready", "loading" or "failed"
sub onLoadStatusChanged()
    ' eslint-disable-next-line roku/no-print
    ? "LOAD STATUS FOR BITMOVINPLAYER LIBRARY: "; m.bitmovinPlayerSDK.loadStatus

    if m.bitmovinPlayerSDK.loadStatus = "ready" then
        ' Once the library is loaded and ready, we can use it to reference the BitmovinPlayer
        m.bitmovinPlayer = CreateObject("roSGNode", "BitmovinPlayerSDK:BitmovinPlayer")
        m.top.appendChild(m.bitmovinPlayer)
        m.BitmovinFunctions = m.bitmovinPlayer.BitmovinFunctions
        m.BitmovinFields = m.bitmovinPlayer.BitmovinFields
        m.bitmovinPlayer.ObserveField(m.BitmovinFields.ERROR, "catchVideoError")
        m.bitmovinPlayer.ObserveField(m.BitmovinFields.WARNING, "catchVideoWarning")
        m.bitmovinPlayer.ObserveField(m.BitmovinFields.SEEK, "onSeek")
        m.bitmovinPlayer.ObserveField(m.BitmovinFields.SEEKED, "onSeeked")

        m.convivaAnalytics = CreateObject("roSGNode", "ConvivaAnalytics")
        player = m.bitmovinPlayer
        customerKey = "YOUR_CUSTOMER_KEY"
        config = {
            debuggingEnabled: true,
            gatewayUrl: "YOUR_GATEWAY_URL" ' TOUCHSTONE_SERVICE_URL for testing
        }
        m.convivaAnalytics.callFunc("setup", player, customerKey, config)
        contentMetadataOverrides = {
            playerName: "Conviva Integration Test Channel",
            viewerId: "MyAwesomeViewerId",

        }
        contentMetadataOverrides.SetModeCaseSensitive()
        contentMetadataOverrides.customMetadata = {}
        contentMetadataOverrides.customMetadata.SetModeCaseSensitive()
        contentMetadataOverrides.customMetadata["CustomKey"] = "Custom Value"

        m.convivaAnalytics.callFunc("monitorVideo", contentMetadataOverrides)

        m.bitmovinPlayer.callFunc(m.BitmovinFunctions.SETUP, m.playerConfig)

        ' You can then update metadata during session as resource,streamUrl, bitrate and encoding Frame rate

        '        m.convivaAnalytics.callFunc("updateContentMetadata", contentMetadataOverrides)
    end if
end sub

sub catchVideoError()
    ' eslint-disable-next-line roku/no-print
    ? "ERROR: "; m.bitmovinPlayer.error.code.toStr() + ": " + m.bitmovinPlayer.error.message
end sub

sub catchVideoWarning()
    ' eslint-disable-next-line roku/no-print
    ? "WARNING: "; m.bitmovinPlayer.warning.code.toStr() + ": " + m.bitmovinPlayer.warning.message
end sub

sub onSeek()
    ' eslint-disable-next-line roku/no-print
    ? "SEEKING"
end sub

sub onSeeked()
    ' eslint-disable-next-line roku/no-print
    ? "SEEKED: "; m.bitmovinPlayer.seeked
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    handled = false
    ? "##### key received!" ' eslint-disable-line roku/no-print
    if press and (key = "down" or key = "up") then
        handled = true
        if key = "up" then
            m.playerConfig = getExamplePlayerConfig2()
        else
            m.playerConfig = getExamplePlayerConfig()
        end if
        ' m.bitmovinPlayer.callFunc(m.BitmovinFunctions.SETUP, m.playerConfig)
        contentMetadataOverrides = {
            playerName: "Conviva Integration Test Channel 2",
            viewerId: "MyAwesomeViewerId" + key,
            customMetadata: {
                CustomKey: "CustomValue",
                KeyPress: key
            }
        }
        m.convivaAnalytics.callFunc("monitorVideo", contentMetadataOverrides)

        m.bitmovinPlayer.callFunc(m.BitmovinFunctions.LOAD, m.playerConfig.source)
    end if
    return handled
end function