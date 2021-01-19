sub init()
  reset()
end sub

sub setOverrides(newValue)
  if m.playbackStarted
    print "[Conviva Analytics] Playback has started. Only some metadata attributes will be updated"
  end if

  m.metadataOverrides = newValue
end sub

sub setPlaybackStarted(value)
  m.playbackStarted = value
end sub

function build()
  if not m.playbackStarted
    if m.contentMetadata.assetName = invalid
      m.contentMetadata.assetName = getAssetName()
    end if

    m.contentMetadata.viewerId = getViewerId()
    m.contentMetadata.isLive = getStreamType()
    m.contentMetadata.playerName = getApplicationName()
    m.contentMetadata.contentlength = getDuration()
    m.contentMetadata.customMetadata={}
	  m.contentMetadata.customMetadata.SetModeCaseSensitive()
    m.contentMetadata.customMetadata = getCustom()
  end if

  m.contentMetadata.encodedFramerate = getEncodedFrameRate()
  m.contentMetadata.defaultReportingResource = getDefaultResource()
  m.contentMetadata.streamUrl = getStreamUrl()

  return m.contentMetadata
end function

sub setAssetName(value)
  m.metadata.assetName = value
end sub

function getAssetName()
  if m.metadataOverrides.assetName <> invalid
    return m.metadataOverrides.assetName
  else
    return m.metadata.assetName
  end if
end function

sub setViewerId(value)
  m.metadata.viewerId = value
end sub

function getViewerId()
  if m.metadataOverrides.viewerId <> invalid
    return m.metadataOverrides.viewerId
  else
    return m.metadata.viewerId
  end if
end function

sub setStreamType(value)
  m.metadata.isLive = value
end sub

function getStreamType()
  if m.metadataOverrides.streamType <> invalid
    return m.metadataOverrides.isLive
  else
    return m.metadata.isLive
  end if
end function

sub setApplicationName(value)
  m.metadata.playerName = value
end sub

function getApplicationName()
  if m.metadataOverrides.playerName <> invalid
    return m.metadataOverrides.playerName
  else
    return m.metadata.playerName
  end if
end function

sub setCustom(value)
  m.metadata.customMetadata={}
  m.metadata.customMetadata.SetModeCaseSensitive()
  m.metadata.customMetadata = value
end sub

function getCustom()
  if m.metadataOverrides.customMetadata <> invalid and m.metadata.customMetadata <> invalid
    m.metadataOverrides.customMetadata.Append(m.metadata.customMetadata) ' Keep our internal ones
    return m.metadataOverrides.customMetadata ' Append is modifying the original object
  else if m.metadataOverrides.customMetadata <> invalid
    return m.metadataOverrides.customMetadata
  else if m.metadata.customMetadata <> invalid
    return m.metadata.customMetadata
  end if
  return {}
end function

sub setDuration(value)
  m.metadata.contentlength = value
end sub

function getDuration()
  if m.metadataOverrides.contentlength <> invalid
    return m.metadataOverrides.contentlength
  else
    return m.metadata.contentlength
  end if
end function

sub setEncodedFrameRate(value)
  m.metadata.encodedFramerate = value
end sub

function getEncodedFrameRate()
  if m.metadataOverrides.encodedFramerate <> invalid
    return m.metadataOverrides.encodedFramerate
  else
    return m.metadata.encodedFramerate
  end if
end function

sub setDefaultResource(value)
  m.metadata.defaultReportingResource = value
end sub

function getDefaultResource()
  if m.metadataOverrides.defaultReportingResource <> invalid
    return m.metadataOverrides.defaultReportingResource
  else
    return m.metadata.defaultReportingResource
  end if
end function

sub setStreamUrl(value)
  m.metadata.streamUrl = value
end sub

function getStreamUrl()
  if m.metadataOverrides.streamUrl <> invalid
    return m.metadataOverrides.streamUrl
  else
    return m.metadata.streamUrl
  end if
end function

sub reset()
  m.metadataOverrides = resetMetaData()
  m.metadata = resetMetaData()
  m.contentMetadata = resetMetaData()
  m.playbackStarted = false
end sub

function resetMetaData()
    metaData = {}

    metaData.customMetadata = {}

    metaData.defaultReportingBitrateKbps = invalid

    metaData.defaultReportingResource = invalid

    metaData.viewerId = invalid

    metaData.playerName = invalid

    metaData.streamUrl = invalid

    metaData.streamUrls = invalid

    metaData.isLive = invalid

    metaData.streamFormat = invalid

    metaData.contentLength = invalid

    metaData.encodedFramerate = invalid
    return metaData
end function
