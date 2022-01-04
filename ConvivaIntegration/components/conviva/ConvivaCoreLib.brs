' Copyright: Conviva Inc. 2011-2012
' Conviva LivePass Brightscript Client library for Roku devices
' LivePass Version: 3.0.15
' authors: Alex Roitman <shura@conviva.com>
'          George Necula <necula@conviva.com>
'

'==== Public interface to the ConvivaLivePass library ====
' The code below should be used in the integrations.
'==== Public interface to the ConvivaLivePass library ====

'''
''' ConvivaLivePassInstace is a singleton that returns ConvivaLivePass
''' that was created with ConvivaLivePassInit
'''
function ConvivaLivePassInstance() as dynamic
    globalAA = getGLobalAA()
    return globalAA.ConvivaLivePass
end function

'''
''' ConvivaWait() should be used instead of regular wait()
'''
''' <param name="customWait">a customWait function for the third party,
''' in case they have a similar replacement for wait() </param>
'''
function ConvivaWait(timeout as integer, port as object, customWait as dynamic) as dynamic
    Conviva = ConvivaLivePassInstance()
    return Conviva.utils.wait(timeout, port, customWait, Conviva)
end function

'''
''' ConvivaContentInfo class
''' Encapsulates the information about a video stream
''' <param name="assetName">an asset name  (video title) for this session </param>
''' <param name="tags">a dictionary with *case-sensitive* keys corresponding to the tags</param>
'''
function ConvivaContentInfo (assetName = invalid as dynamic, tags = invalid as dynamic)
    self = { }
    ' Sanitizing assetName and tags
    ' DE-2710: Assetname need to be invalid till it is explicitly set
    if type(assetName) = "roString" or type(assetName) = "String"
        self.assetName = assetName
    else if type(tags) = "roString" or type(tags) = "String"
        self.assetName = tags
    end if

    self.tags = {}
    ' A set of key-value pairs used in resource selection and policy evaluation
    if type(tags) = "roAssociativeArray"
        for each tk in tags
            self.tags[tk] = tags[tk]
        end for
    else if type(assetName) = "roAssociativeArray"
        for each tk in assetName
            self.tags[tk] = assetName[tk]
        end for
    end if

    '''''''''''''''''''''''''''''''''''''''''
    '''
    ''' The remaining fields are optional
    '''
    '''''''''''''''''''''''''''''''''''''''''

    ' Set this to the bitrate (1000 bits-per-second) to be used for the integrations
    ' where the streamer does not know the bitrate being played. This value is used
    ' until the streamer reports a bitrate.
    self.defaultReportingBitrateKbps = invalid

    ' Set this to a string that will be used as the resource name for the integrations
    ' where the streamer does not itself know the resource being played.
    self.defaultReportingResource = invalid

    ' A string identifying the viewer.
    self.viewerId = invalid

    ' PD-7686:
    ' A string identifying the player in use, preferably human-readable.
    ' If you have multiple players, this can be used to distinguish between them.
    self.playerName = invalid

    ' The URL from which video is loaded.
    ' Note: If this changes during a session, there is no need to update
    ' this value - just use the URL from which loading initially occurs.
    ' CSR-1236: Adding support for StreamUrl along with StreamUrls part of ContentInfo
    self.streamUrl = invalid

    ' This is the complete path to the manifest file on all the CDNs for the asset being played.
    ' The ordering of this array should be aligned with the StreamUrls field of the content metadata roAssociativeArray passed to the ifVideoScreen.SetContent()
    self.streamUrls = invalid

    ' Set to true if the session includes live content, and false otherwise.
    self.isLive = invalid

    ' PD-8962: Smooth Streaming support
    ' Allow player to specify streamFormat if known
    self.streamFormat = invalid

    ' PD-10673: contentLength support
    self.contentLength = invalid

    ' DE-1185: Mutable metadata, need to add encodedFramerate part of contentinfo
    self.encodedFramerate = invalid
    return self
end function


'''------------
''' Conviva LivePass class
''' Constructs, initializes and returns a ConvivaLivePass object.
'''
''' <param name="apiKey">a key assigned by Conviva to uniquely identify a Conviva customer </param>
''' <returns>A ConvivaLivePass object
function ConvivaLivePassInit (apiKey as string)
    return ConvivaLivePassInitWithSettings(apiKey, invalid)
end function

'==== End of the Public interface to the ConvivaLivePass library ====
' The code below should not be accessed directly by integrations.
'==== End of the Public interface to the ConvivaLivePass library ====


'''------------
''' Conviva LivePass class
''' Constructs, initializes and returns a ConvivaLivePass object.
'''
''' <param name="apiKey">a key assigned by Conviva to uniquely identify a Conviva customer </param>
''' <param name="convivaSettings">an optional associative array with advanced configuration settings. This parameter should be used only with guidance from Conviva</param>
''' <returns>A ConvivaLivePass object
function ConvivaLivePassInitWithSettings (apiKey as object, convivaSettings=invalid as object)
    ' Singleton mechanism
    conviva = ConvivaLivePassInstance()

    ' PD-15618: stronger detection code for properly initialized library instance
    if type(conviva) = "roAssociativeArray" and (type(conviva.apiKey) = "roString" or  type(conviva.apiKey) = "String") and type(conviva.cleanupSession) = "roFunction" then
        return conviva
    end if

    if apiKey = invalid
        print "ERROR: ConvivaLivePassInstance creation is failed due to lack of apiKey"
        return invalid
    end if

    self = {}

    self.SESSION_TYPE = {
        GLOBAL: 0,
        CONTENT: 1,
        AD: 2
    }

    self.PLAYER_STATES = {
        STOPPED:        "1",
        BUFFERING:      "6",
        PLAYING:        "3",
        PAUSED:        "12"
        NOT_MONITORED:  "98"
    }

    self.AD_POSITION = {
        'The ad is a bumper, kicking in before content.
        BUMPER: "BUMPER",
        'The ad is a preroll, kicking in before content.
        PREROLL: "PREROLL",
        'The ad is a midroll, kicking in during content.
        MIDROLL: "MIDROLL",
        'The ad is a postroll, kicking in after content.
        POSTROLL: "POSTROLL"
    }

    'Possible types of ad errors, use ERROR_UNKNOWN if the error type is not found below.
    self.AD_ERRORS = {
        ERROR_UNKNOWN: "ERROR_UNKNOWN",
        ERROR_IO: "ERROR_IO",
        ERROR_TIMEOUT: "ERROR_TIMEOUT",
        ERROR_NULL_ASSET: "ERROR_NULL_ASSET",
        ERROR_MISSING_PARAMETER: "ERROR_MISSING_PARAMETER",
        ERROR_NO_AD_AVAILABLE: "ERROR_NO_AD_AVAILABLE",
        ERROR_PARSE: "ERROR_PARSE",
        ERROR_INVALID_VALUE: "ERROR_INVALID_VALUE",
        ERROR_INVALID_SLOT: "ERROR_INVALID_SLOT",
        ERROR_3P_COMPONENT: "ERROR_3P_COMPONENT",
        ERROR_UNSUPPORTED_3P_FEATURE: "ERROR_UNSUPPORTED_3P_FEATURE",
        ERROR_DEVICE_LIMIT: "ERROR_DEVICE_LIMIT",
        ERROR_UNMATCHED_SLOT_SIZE: "ERROR_UNMATCHED_SLOT_SIZE"
    }

    'Possible type of ad events that may occur during the life time of ad in a content.
    self.AD_EVENTS = {
        AD_REQUESTED: "Conviva.AdRequested",
        AD_RESPONSE: "Conviva.AdResponse",
        AD_SLOT_STARTED: "Conviva.SlotStarted",
        AD_SLOT_ENDED: "Conviva.SlotEnded",
        CONTENT_PAUSED: "Conviva.PauseContent",
        CONTENT_RESUMED: "Conviva.ResumeContent",
        POD_START: "Conviva.PodStart",
        POD_END: "Conviva.PodEnd",
        AD_ATTEMPTED: "Conviva.AdAttempted",
        AD_IMPRESSION_START: "Conviva.AdImpression",
        AD_START: "Conviva.AdStart",
        AD_FIRST_QUARTILE: "Conviva.AdFirstQuartile",
        AD_MID_QUARTILE: "Conviva.AdMidQuartile",
        AD_THIRD_QUARTILE: "Conviva.AdThirdQuartile",
        AD_COMPLETE: "Conviva.AdComplete",
        AD_END: "Conviva.AdEnd",
        AD_IMPRESSION_END: "Conviva.AdImpressionEnd",
        AD_SKIPPED: "Conviva.AdSkipped",
        AD_ERROR: "Conviva.AdError",
        AD_PROGRESS: "Conviva.AdProgress",
        AD_CLOSE: "Conviva.AdClose"
    }

    'Ad technologies
    self.AD_TECHNOLOGY = {
        CLIENT_SIDE: "Client-Side",
        SERVER_SIDE: "Server-Side"
    }

    'Ad Serving type
    self.AD_SERVING_TYPE = {
        INLINE: "Inline",
        WRAPPER: "Wrapper"
    }

    'Ad types
    self.AD_TYPE = {
        VPAID: "VPAID",
        BLACKOUT: "Black out slate",
        TECHNICAL_DIFFICULTIES: "Technical difficulties slate",
        COMMERCIAL_BREAK: "Commercial break slate",
        OTHER: "Other slate",
        REGULAR: "Regular slate"
    }

    'Ad Category
    self.AD_CATEGORY = {
        NATIONAL: "National",
        LOCAL: "Local",
        OTHER: "Other"
    }

    self.OPTION_EXTERNAL_BITRATE_REPORTING = "externalBitrateReporting"
    self.OPTION_EXTERNAL_CDN_REPORTING = "externalCdnServerIpReporting"

    self.StreamerError = {}
    self.StreamerError.SEVERITY_WARNING = false             ' boolean for warning error
    self.StreamerError.SEVERITY_FATAL = true                ' boolean for fatal error

    self.utils = cwsConvivaUtils()
    self.sendLogs = false
    self.cfg = self.utils.convivaSettings
    ' Copy the settings over
    if convivaSettings <> invalid then
        for each key in convivaSettings:
            self.cfg[key] = convivaSettings[key]
        end for
        ' CSR-2446: Invalid setting object fix
        self.cfg.gatewayUrl = self.utils.createConvivaCwsGatewayUrl(apiKey, convivaSettings.gatewayUrl)
    else
        self.cfg.gatewayUrl = self.utils.createConvivaCwsGatewayUrl(apiKey, invalid)
    end if

    self.apiKey  = apiKey

    self.instanceId = self.utils.randInt()

    self.clId    = self.utils.readLocalData ("clientId")
    if self.clId = "" then
        self.clId = "0" ' This will signal to the back-end that we need a new client id
    end if

    self.session = invalid
    self.globalSession = invalid
    self.adsession = invalid
    self.regexes = self.utils.regexes

    self.log = function (msg as string)
         m.utils.log(msg)
    end function

    ' Collect the platform metadata
    self.devinfo = CreateObject("roDeviceInfo")
    self.platformMeta = {
        sch : "rk1",  ' The schema name
        m : self.devinfo.GetModel(),
        dt : self.devinfo.GetDisplayType(),
        dm : self.devinfo.GetDisplayMode()
    }
    ' Roku 9.2 and above supports GetOSVersion method and it '
    if self.devinfo.GetOSVersion() <> invalid
      self.platformMeta.v = self.devinfo.GetOSVersion().major +"."+self.devinfo.GetOSVersion().minor +"."+self.devinfo.GetOSVersion().revision+". build "+self.devinfo.GetOSVersion().build
    end if

    self.utils.log("CWS init done")

    ''
    '' Clean the Conviva LivePass
    ''
    self.cleanup = function () as void
        self = m
        if self.utils = invalid then
            ' Already cleaned
            return
        end if
        self.utils.log("LivePass.cleanup")

        if self.session <> invalid then
            self.utils.log("Destroying session "+stri(self.session.sessionId))
            self.session.cleanup( )
            self.utils.log("Session destroyed")
        end if

        'Clean up global session if created by this client
        if self.globalSession <> invalid then
            self.utils.log("Destroying global session ")
            self.globalSession.cleanup( )
            self.utils.log("Global Session destroyed")
        end if

        self.clId = invalid
        self.session = invalid
        self.globalSession = invalid
        self.devinfo = invalid
        self.utils.cleanup ()
        self.utils = invalid
        self.positionHeadCheck = 0

        globalAA = getGLobalAA()
        globalAA.delete("ConvivaLivePass")

    end function


    '''
    ''' createConvivaSession : Create a monitoring session, without Conviva PreCision control.
    ''' screen - the roSGscreen or  boolean for null streamer or monitoring
    ''' contentInfo - an instance of ConvivaContentInfo with fields set to appropriate values
    ''' notificationPeriod - the interval in seconds to receive playback position events from the screen. This
    '''                      parameter is necessary because Conviva LivePass must change the default PositionNotificationPeriod
    '''                      to 1 second.
    ''' video - video node object for registering the events waiting on port
    ''' options - options for allowing or disabling external bitrate reporting, by default external bitrate is disabled
    self.createSession = function (screen as object , contentInfo as object, positionNotificationPeriod as float, video as object, options = invalid as object) as object
        self = m
        self.utils.log("createSession with  Roku Integration API")

        if self.utils = invalid then
            print "ERROR: called createSession on uninitialized LivePass"
            return invalid
        end if

        if self.session <> invalid then
            self.utils.log("Automatically closing previous session with id "+stri(self.session.sessionId))
            self.cleanupSession(self.session)
        end if
        sess = cwsConvivaSession(self, screen, contentInfo, positionNotificationPeriod, video, self.SESSION_TYPE.CONTENT, options)
        self.session = sess
        self.attachStreamer()
        return sess
    end function

    '''
    ''' createConvivaAdSession : Create a monitoring session, without Conviva PreCision control.
    ''' contentSession - the content session object in which current ad is played
    ''' screen - the roSGscreen or boolean for null streamer or monitoring
    ''' contentInfo - an instance of ConvivaContentInfo with fields set to appropriate ad metadata values
    ''' notificationPeriod - the interval in seconds to receive playback position events from the screen. This
    '''                      parameter is necessary because Conviva LivePass must change the default PositionNotificationPeriod
    '''                      to 1 second.
    ''' video - video node object for registering the events waiting on port
    ''' options - options for allowing or disabling external bitrate reporting, by default external bitrate is disabled
    self.createAdSession = function (contentSession as object, screen as object, contentInfo as object, positionNotificationPeriod as float, video as object, options = invalid as object) as object
        self = m
        self.utils.log("createAdSession with  Roku  Integration API")

        'Check if library is initialized
        if self.utils = invalid then
            print "ERROR: called createSession on uninitialized LivePass"
            return invalid
        end if

        'Check if content session is valid
        if contentSession = invalid then
            self.utils.log("Content session does not exist! Cannot create adSession")
            return invalid
        end if

        'Check if the session object passed is content session object
        if contentSession.sessionId <> self.session.sessionId or contentSession.sessionType <> self.SESSION_TYPE.CONTENT
            self.utils.log("Content session is invalid! Cannot create adSession")
            return invalid
        end if

        'If an ad session already started, clean it up before creating new ad session
        if self.adsession <> invalid then
            self.utils.log("Automatically closing previous session with id "+stri(self.adsession.sessionId))
            self.cleanupSession(self.adsession)
        end if

        'create a new ad session
        contentInfo.tags["c3.csid"] = stri(contentSession.sessionId).trim()
        if contentInfo.viewerId = invalid or contentInfo.viewerId = ""
            contentInfo.viewerId = contentSession.contentInfo.viewerId
        end if
        if contentInfo.playerName = invalid or contentInfo.playerName = ""
            contentInfo.playerName = contentSession.contentInfo.playerName
        end if
        sess = cwsConvivaSession(self, screen, contentInfo, positionNotificationPeriod, video, self.SESSION_TYPE.AD, options)
        self.adsession = sess
        self.attachAdStreamer()
        return sess
    end function

    '''
    ''' sendSessionEvent - send Conviva Player Insight Event, with a name and a list of key value pair as event attributes.
    '''
    ''' session - returned by the createSession
    ''' eventName - a name for the event
    ''' eventAttributes - a dictionary of key value pair associated with the event. The dictionary is modified in place.
    self.sendSessionEvent = function (session as object, eventName as string, eventAttributes as object) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called sendSessionEvent on uninitialized LivePass"
            return
        end if
        if self.checkCurrentSession(session)
            self.utils.log("sendSessionEvent "+eventName)

            evt = {
                t: "CwsCustomEvent",
                name: eventName
            }

            ' DE-2710: attr is an optional field, add only when count > 0
            if eventAttributes <> invalid and type(eventAttributes) = "roAssociativeArray" and eventAttributes.count() > 0
                evt["attr"] = eventAttributes
            end if
            session.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    '''
    ''' sendEvent - send Conviva Player Insight Event, with a name and a list of key value pair as event attributes.
    '''
    ''' eventName - a name for the event
    ''' eventAttributes - a dictionary of key value pair associated with the event. The dictionary is modified in place.
    self.sendEvent = function (eventName as string, eventAttributes as object) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called sendEvent on uninitialized LivePass"
            return
        end if
        ' Check that the global session exists, if not then create new global session.
        if self.globalSession = invalid then
            contentinfo = ConvivaContentInfo()
            sess = cwsConvivaSession(self, false, contentinfo, 1.0, invalid, self.SESSION_TYPE.GLOBAL, invalid)
            self.globalSession = sess
        end if
        self.utils.log("sendEvent "+eventName)

        evt = {
            t: "CwsCustomEvent",
            name: eventName
        }

        ' DE-2710: attr is an optional field, add only when count > 0
        if eventAttributes <> invalid and type(eventAttributes) = "roAssociativeArray" and eventAttributes.count() > 0
            evt["attr"] = eventAttributes
        end if
        self.globalSession.cwsSessSendEvent(evt.t, evt)
    end function

    '''
    ''' setPlayerState - set a play state for a given session. Used mainly in ad insights
    '''
    ''' session - returned by the createAdSession or createSession
    ''' playerState - one of the player states as defined in LivePass.PLAYER_STATES enum
    self.setPlayerState = function (session as object, playerState as string) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called setPlayerState on uninitialized LivePass"
            return
        end if
        self.checkCurrentSession(session)
        self.utils.log("setPlayerState "+playerState)
        session.cwsSessOnStateChange(playerState, invalid)
    end function

    '''
    ''' reportError - report errors occured with an error string and type for the session.
    '''
    ''' session - returned by the createSession
    ''' eventString - an error string that has to be reported as part of the session
    ''' errorType - an error type boolean value to be reported for fatal(true) or warning(false),
    '''             even if not errorType is not set by default will be considered as fatal
    self.reportError = function (session as object, eventString as string, errorType = true as Dynamic) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called reportError on uninitialized LivePass"
            return
        end if
        if self.checkCurrentSession(session)
            self.utils.log("reportError "+eventString)
            ' Sanitize errorType for non boolean content
            if type(errorType) <> "roBoolean" and type(errorType) <> "Boolean"
                errorType = true ' by default set to fatal, if not specified
            end if
            evt = {
                t: "CwsErrorEvent",
                ft: errorType,
                err: eventString
            }

            session.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    '''
    ''' setCurrentStreamInfo : Set the current bitrate and/or current resource
    '''
    ''' bitrateKbps - the new bitrate (ignored if -1)
    ''' resource    - the new resource (ignored if invalid)
    self.setCurrentStreamInfo = function (session as object, bitrateKbps as dynamic, resource as dynamic) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called setCurrentStreamInfo on uninitialized LivePass"
            return
        end if
        self.utils.log("setCurrentStreamInfo")
        if self.checkCurrentSession(session)
            session.setCurrentStreamInfo(bitrateKbps, resource)
        end if
    end function

    '''
    ''' setBitratekbps : Set the current bitrate
    '''
    ''' bitrateKbps - the new bitrate (ignored if -1)
    self.setBitrateKbps = function (session as object, bitrateKbps as dynamic) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called setBitrateKbps on uninitialized LivePass"
            return
        end if
        if session.externalBitrateReporting = false
            self.utils.log("ERROR: setBitrateKbps() call ignored, enable external bitrate reporting first")
            return
        end if
        self.utils.log("setBitrateKbps")
        if self.checkCurrentSession(session)
            session.cwsSessOnBitrateChange(bitrateKbps, true)
        end if
    end function

    '''
    ''' setCurrentStreamMetadata : Set various metadata parameters for the stream
    '''  - This method will be deprecated in future, as updateContentMetadata API is introduced
    '''    for consistency across Conviva supported platforms. This method ensures the backward compatibility
    '''  - duration (string - duration of the stream in seconds)
    '''  - framerate (string - encoded framerate in fps)
    ''' If the callback is called multiple times, the most recent value for each key will be used. For
    ''' example, calling the callback first with { duration : "100" } and immediately thereafter with
    ''' { framerate : "30" } is equivalent to calling it once with { duration : "100", framerate : "30" }.
    self.setCurrentStreamMetadata = function (session as object, metadata as object) as void
        self = m
        print "WARNING: setCurrentStreamMetadata API will be deprecated in future and only updateContentMetadata API will be supported"
        ' Converting the string into integer of duration for updateContentMetadata()
        if metadata.duration <> invalid then
            if type(metadata.duration) = "String" or type(metadata.duration) = "roString"
                metadata.contentLength = strtoi(metadata.duration)
            else if type(metadata.duration) = "Integer" or type(metadata.duration) = "roInteger" or type(metadata.duration) = "roInt"
                metadata.contentLength = metadata.duration
            end if
           ' delete the field duration part of metadata as it is unused in updateContentMetadata()
            metadata.Delete("duration")
        end if

        ' Converting the string into integer of framerate for updateContentMetadata() and updating the encodedFramerate
        ' to update the field part of ConvivaContentInfo
        if metadata.framerate <> invalid
            if type(metadata.framerate) = "String" or type(metadata.framerate) = "roString"
                metadata.encodedFramerate = strtoi(metadata.framerate)
            else if type(metadata.framerate) = "Integer" or type(metadata.framerate) = "roInteger" or type(metadata.framerate) = "roInt"
                metadata.encodedFramerate = metadata.framerate
            end if
            ' deleting the field framerate part of metadata as it is unused in updateContentMetadata()
            metadata.Delete("framerate")
        end if
        self.updateContentMetadata(session, metadata)
    end function

    '''
    ''' updateContentMetadata : Set various metadata parameters for the stream
    '''
    ''' The metadata object should be a dictionary from metadata field names to metadata values (as strings).
    ''' The names of the valid keys are defined in ConvivaLivePass as constants:
    '''  - contentLength (contentLength of the stream in seconds)
    '''  - streamUrl (The URL from which video is loaded)
    '''  - encodedFramerate (encoded framerate in fps)
    '''  - assetName (video title for the session)
    '''  - isLive (true if the session includes live content, and false otherwise)
    '''  - playerName (a string identifying the player in use, preferably human-readable)
    '''  - viewerId (a string identifying the viewer)
    '''  - tags (a dictionary with case-sensitive keys corresponding to the tags)
    '''  - defaultReportingResource (the resource being played)
    ''' Other keys are ignored.
    ''' If the callback is called multiple times, the most recent value for each key will be used. For
    ''' example, calling the callback first with { contentLength : 100 } and immediately thereafter with
    ''' { encodedFramerate : 30 } is equivalent to calling it once with { contentLength : 100, encodedFramerate : 30 }.
    self.updateContentMetadata = function (session as object, metadata as object) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called updateContentMetadata on uninitialized LivePass"
            return
        end if
        self.utils.log("updateContentMetadata")
        if self.checkCurrentSession(session)
            session.updateContentMetadata(metadata)
        end if
    end function

    '''
    ''' Update videonode after session creation after object is created
    self.updateVideoNode = function (videoNode as object) as void
        self = m
        if self.session <> invalid then
            self.session.video = videoNode
            self.session.video.notificationinterval = self.session.notificationPeriod
        end if
        if self.adsession <> invalid then
            self.adsession.video = videoNode
            self.adsession.video.notificationinterval = self.adsession.notificationPeriod
        end if
    end function
    '''
    ''' cleanupSession : should be called when a video session is over
    ''' Note: this is used to detect properly initialized library objects. Be careful when renaming this.
    '''
    self.cleanupSession = function (session) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called cleanupSession on uninitialized LivePass"
            return
        end if
        self.utils.log("Cleaning session")
        if session <> invalid
            self.utils.prevSequence = -1
            self.utils.baseAudioSeq = -1
            self.utils.baseVideoSeq = -1
            if self.checkCurrentSession(session)
                session.cleanup ()
            end if
            if session.sessionType = self.SESSION_TYPE.CONTENT
                if self.utils.downloadSegments <> invalid
                    self.utils.downloadSegments.Clear()
                end if
                self.session = invalid
                'Clean up global session too
                if self.globalSession <> invalid
                    self.globalSession.cleanup ()
                    self.globalSession = invalid
                end if
            else if session.sessionType = self.SESSION_TYPE.AD
                self.adsession = invalid
            end if
        end if
    end function

    '''
    ''' toggleTraces : toggle the printing of the Conviva traces to the debugging console
    '''
    self.toggleTraces = function (toggleOn as boolean) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called toggleTraces on uninitialized LivePass"
            return
        end if
        self.utils.log("toggleTraces")
        self.utils.convivaSettings.enableLogging = toggleOn
    end function

    ' Check that the given session is the current one
    self.checkCurrentSession = function (session as object) as boolean
        self = m
        if session = invalid or self.session = invalid then
            self.utils.err("Called cleanupSession for an untracked session")
            return false
        end if
        if session.sessiontype = self.SESSION_TYPE.CONTENT and session.sessionId <> self.session.sessionId ' content session'
            self.utils.err("Called cleanupSession for an untracked session")
            return false
        else if self.adsession <> invalid and session.sessiontype = self.SESSION_TYPE.AD and session.sessionId <> self.adsession.sessionId ' ad session'
            self.utils.err("Called cleanupSession for an untracked session")
            return false
        end if
        return true
    end function

    '''
    ''' attachStreamer : Attach a streamer to the monitor and resume monitoring if suspended
    '''
    self.attachStreamer = function (screen=invalid as object) as void
        self = m
        if self.session = invalid then
            print "ERROR: called attachStreamer on uninitialized LivePass"
            return
        end if
        self.utils.log("attachStreamer")
	if screen <> invalid then
        self.session.screen = screen
	end if
        if self.session.screen = invalid ' attach with null streamer
            self.session.cwsSessOnStateChange(self.session.ps.notmonitored, invalid)
            self.session.screen = false
        else                ' attach with proper streamer
            ' Not guaranteed to work, see CSR-103. Extra integration step needed.
            self.session.screen = true
            if self.session.video <> invalid then
                self.session.video.notificationinterval = self.session.notificationPeriod
                if self.session.video.GetField("state") = "playing"
                    self.session.cwsSessOnStateChange(self.session.ps.playing, invalid)
                else if self.session.video.GetField("state") = "paused"
                    self.session.cwsSessOnStateChange(self.session.ps.paused, invalid)
                else if self.session.video.GetField("state") = "buffering"
                    self.session.cwsSessOnStateChange(self.session.ps.buffering, invalid)
                end if
            end if

            ' Restoring the prevBitrate reported during detach streamer as a fallback
            ' even during ad playback, Roku doesn't report bitrate
            if self.session.prevBitrateKbps <> invalid
                self.session.cwsSessOnBitrateChange(self.session.prevBitrateKbps, false)
                self.session.prevBitrateKbps = invalid
            end if
        end if
    end function

    '''
    ''' attachAdStreamer : Attach an ad streamer to the ad monitor and resume monitoring if suspended
    ''' This method is only used at the start of ad playback after creating an ad session
    '''
    self.attachAdStreamer = function (screen=invalid as object) as void
        self = m
        if self.adsession = invalid then
            print "ERROR: called attachAdStreamer on uninitialized LivePass"
            return
        end if
        self.utils.log("attachAdStreamer")
        if screen <> invalid then
            self.adsession.screen = screen
        end if
        if self.adsession.screen = invalid ' attach with null streamer
            self.adsession.cwsSessOnStateChange(self.adsession.ps.notmonitored, invalid)
            self.adsession.screen = false
        else                ' attach with proper streamer
            ' Not guaranteed to work, see CSR-103. Extra integration step needed.
            self.adsession.screen = true
            if self.adsession.video <> invalid  then
                self.adsession.video.notificationinterval = self.adsession.notificationPeriod
                if self.adsession.video.GetField("state") = "playing"
                    self.adsession.cwsSessOnStateChange(self.adsession.ps.playing, invalid)
                else if self.adsession.video.GetField("state") = "paused"
                    self.adsession.cwsSessOnStateChange(self.adsession.ps.paused, invalid)
                else if self.adsession.video.GetField("state") = "buffering"
                    self.adsession.cwsSessOnStateChange(self.adsession.ps.buffering, invalid)
                end if
            end if
            ' Restoring the prevBitrate reported during detach streamer as a fallback
            ' even during ad playback, Roku doesn't report bitrate
            if self.adsession.prevBitrateKbps <> invalid
                self.adsession.cwsSessOnBitrateChange(self.adsession.prevBitrateKbps, false)
                self.adsession.prevBitrateKbps = invalid
            end if
        end if
    end function

    '''
    ''' detachStreamer : Pause monitoring such that it can be restarted later and detach from current streamer
    '''
    self.detachStreamer = function () as void
        self = m
        if self.session = invalid then
            print "ERROR: called detachStreamer on uninitialized LivePass"
            return
        end if
        self.utils.log("detachStreamer")
        self.session.cwsSessOnStateChange(self.session.ps.notmonitored, invalid)
        self.session.screen = false
    end function

    '''
    ''' adStart : Notifies our library that an ad is about to be played.
    '''           Suspend the accumulation of join time.
    '''           Use, e.g., when an ad is starting and the time should not be counted as part of the join time.
    '''
    self.adStart = function () as void
        self = m
        if self.session = invalid then
            print "ERROR: called pause join time calculation API on uninitialized LivePass"
            return
        end if
        if self.session.screen = true then
            print "ERROR: called pause join time calculation API after joining"
            return
        end if
        pjt = {
            t: "CwsStateChangeEvent",
                new: {
                    pj: true
            }
        }
        pjt.old = {
                pj: false
        }
        if pjt <> invalid then
            self.session.pj = true
            self.session.cwsSessSendEvent(pjt.t, pjt)
        end if
    end function

    '''
    ''' adEnd : Notifies our library that an ad is over.
    '''         Resume the accumulation of join time.
    '''
    self.adEnd = function () as void
        self = m
        if self.session = invalid then
            print "ERROR: called resume join time calculation API on uninitialized LivePass"
            return
        end if
        if self.session.screen = true then
            print "ERROR: called resume join time calculation API after joining"
            return
        end if
        pjt = {
            t: "CwsStateChangeEvent",
                new: {
                    pj: false
            }
        }
        pjt.old = {
                pj: true
        }
        if pjt <> invalid then
            self.session.pj = false
            self.session.cwsSessSendEvent(pjt.t, pjt)
        end if
    end function

    '''
    ''' setPlayerSeekStart : Reports the player started seeking.
    ''' This API should be called in response to player issued seek start event, or right before you programmatically call player.seekto(seekToPos).
    ''' Note: "player.seekto" syntax is platform dependent.
    ''' session - returned by the createSession
    ''' seekToPos - Seek to position should be set if it's known. Otherwise -1 should be set. Value should be in milliseconds.
    '''
    self.setPlayerSeekStart = function (session as object, seekToPos as integer) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called setPlayerSeekStart on uninitialized LivePass"
            return
        end if
        self.utils.log("setPlayerSeekStart")
        if self.checkCurrentSession(session)
            session.cwsSessOnPlayerSeekStart(seekToPos)
        end if
    end function

    '''
    ''' setPlayerSeekEnd : Reports that player seek has completed, and the player is ready for playback to start again from the new position.
    ''' This API should be called in response to player issued seek end event instead of user seek action.
    ''' session - returned by the createSession
    '''
    self.setPlayerSeekEnd = function (session as object) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called setPlayerSeekEnd on uninitialized LivePass"
            return
        end if
        self.utils.log("setPlayerSeekEnd")
        if self.checkCurrentSession(session)
            session.cwsSessOnPlayerSeekEnd()
        end if
    end function

    self.isCleanupContentSessionSuccessful = function () as boolean
        self = m
        if self.utils = invalid then
            print "ERROR: called isCleanupContentSessionSuccessful on uninitialized LivePass"
            return false
        end if
        return self.utils.isCleanupSuccessful
    end function

    self.setCDNServerIP = function (session as object, cdnServerIPAddress as string) as void
        self = m
        if self.utils = invalid then
            print "ERROR: called setCDNServerIP on uninitialized LivePass"
            return
        end if
        self.utils.log("self.setCDNServerIP")
        if self.checkCurrentSession(session)
            session.cwsSessOnCDNServerIP(cdnServerIPAddress, true)
        end if
    end function

    ' Store ourselves in the globalAA for future use
    globalAA = getGLobalAA()
    globalAA.ConvivaLivePass = self

    return self
end function


'--------------
' Session class
'--------------
function cwsConvivaSession(cws as object, screen as object, contentInfo as object, notificationPeriod as float, video as object, sessionType as integer, options as object) as object
    self = {}
    self.video = video
    if  type(screen) = "roBoolean" and screen = false
        self.screen = invalid
    else
        self.screen = screen
    end if
    self.contentInfo = contentInfo
    self.notificationPeriod = notificationPeriod
    self.lastRequestSent = invalid
    self.lastResponseTimeMs = 0
    self.isReady = false
    self.externalBitrateReporting = false
    self.externalCdnServerIpReporting = false
    self.moduleName = invalid
    if options <> invalid and options.Count() > 0
      if options.DoesExist(cws.OPTION_EXTERNAL_BITRATE_REPORTING) and options[cws.OPTION_EXTERNAL_BITRATE_REPORTING]
        self.externalBitrateReporting = true
      end if
      if options.DoesExist(cws.OPTION_EXTERNAL_CDN_REPORTING) and options[cws.OPTION_EXTERNAL_CDN_REPORTING]
        self.externalCdnServerIpReporting = true
      end if
      if options.moduleName <> Invalid
        self.moduleName = options.moduleName
      end if
    end if

    self.cdnServerStreamUrl = invalid

    self.bl = -1
    self.pht = -1
    self.fw = invalid
    self.cws = cws
    ' DE-2710: Create a copy of session.evs instead of directly copying into hb
    self.evs = []
    self.sessionType = sessionType
    if sessionType = self.cws.SESSION_TYPE.GLOBAL
        self.global = true
    else
        self.global = false
    end if

    'CSR-1967:
    'For PHT check - add 10% approximate boundary in milliseconds (1000 + 100 for 10%)
    self.positionHeadCheck = notificationPeriod * 1100
    ' DE-5057: isCleanupSuccessful reset to false if same livepass instance is reused for the playback
    cws.utils.isCleanupSuccessful = false
    self.utils = cws.utils
    self.devinfo = cws.devinfo

    self.cfg = {}

    self.cfg.maxhbinfos = cws.cfg.maxhbinfos
    self.cfg.csi_en = cws.cfg.csi_en

    self.timer = CreateObject("roTimespan")
    self.timer.Mark()

    self.hbinfos = CreateObject("roArray", cws.cfg.maxhbinfos, true)

    'The values have to be strings because they will be
    'used as keys in other dictionaries.
    self.ps = {
        stopped:        "1",
        'error:         "99",
        buffering:      "6",
        playing:        "3",
        paused:        "12"
        notmonitored:  "98"
    }

    self.sessionId = int(2147483647*rnd(0))
    self.pj = false
    if self.global = true then
        self.sessionFlags = 0 'For global session, session flags "sf" must be 0
    else
        ' DE-2170: Precision code is removed and hence the session flag will be 7
        self.sessionFlags = 7  ' SFLAG_VIDEO | SFLAG_QUALITY_METRICS | SFLAG_BITRATE_METRICS
    end if

    callback = function (sess as dynamic)
         sess.cwsSessSendHb(false)
    end function

    cdnRequest = function (sess as dynamic)
        ' Fire CDN head request only if it is enabled from backend in HB config'
        if sess.cfg.csi_en = true then
            print "CSI_EN is set to true, firing CDN head request"
            sess.utils.sendCDNRequest(sess.cdnServerStreamUrl, sess.cdnCallback, sess)
        end if
    end function

    self.targetIpAddress = invalid
    self.cdnCallback = function (sess as object, success as boolean, resp as string)
        print "recieved CDN HEAD response"
        if success = True
            if sess<> Invalid and sess.targetIpAddress <> invalid and sess.cfg.csi_en = true
                sess.cwsSessOnCDNServerIP(sess.targetIpAddress, false)
            end if
        end if
    end function

    self.hbTimer = self.utils.createTimer(callback, self, self.utils.convivaSettings.heartbeatIntervalMs, "heartbeat")
    self.cdnTimer = self.utils.createTimer(cdnRequest, self, 120000, "cdnTimer")

    if contentInfo.assetName <> invalid
        self.utils.log("Created new session with id "+stri(self.sessionId)+" for asset "+contentInfo.assetName)
    else
        self.utils.log("Created new session with id "+stri(self.sessionId))
    end if

    ' Sanitize the tags
    for each tk in contentInfo.tags
        if contentInfo.tags[tk] = invalid then
            self.utils.log("WARNING: correcting null value for tag key "+tk)
            contentInfo.tags[tk] = "null"
        end if
    end for

    if contentInfo.defaultReportingBitrateKbps <> invalid
        self.utils.log("Error defaultReportingBitrateKbps is deprecated, instead use setBitrateKbps API")
    end if
    ' PD-10673: contentLength support, sanitize
    if (type(contentInfo.contentLength)<>"roInteger" and type(contentInfo.contentLength)<>"roInt" and type(contentInfo.contentLength)<>"Integer") or contentInfo.contentLength < 0 then
        if contentInfo.contentLength <> invalid then
            self.utils.log("Invalid ConvivaContentInfo.contentLength. Expecting >= 0 roInteger.")
        end if
        contentInfo.contentLength = invalid
    end if

    ' PD-8962: Smooth Streaming support
    ' CSR-1288: Fetching streamformat from contentInfo if available instead of auto detection
    if contentInfo.streamFormat <> invalid then
        self.streamFormat = contentInfo.streamFormat
    end if
    self.fw = "Roku Scene Graph"

    if self.streamFormat <> invalid and self.streamFormat <> "mp4" and self.streamFormat <> "ism" and self.streamFormat <> "hls" and self.streamFormat <> "dash" then
        self.utils.log("Received invalid streamFormat from player: " + self.streamFormat)
        self.utils.log("Valid streamFormats : mp4, ism, hls, dash")
        self.streamFormat = invalid
    end if
    self.videoBitrate = -1
    self.audioBitrate = -1
    self.streamingSegmentEventCount = 0
    self.totalBitrate = -1

    self.sessionTimer = CreateObject("roTimespan")
    self.sessionTimer.mark()

    dt = CreateObject("roDateTime")
    self.sessionStartTimeMs = 0# + dt.asSeconds() * 1000.0#  + dt.getMilliseconds ()

    self.eventSeqNumber = 0
    self.psm = cwsConvivaPlayerState(self)

    self.hb = {
        cid : cws.apiKey,
        clid: cws.clId,
        sid: self.sessionId,
        iid : cws.instanceId,
        sf : self.sessionFlags,
        seq: 0,
        pver: cws.cfg.protocolVersion,
        t: "CwsSessionHb",
        clv : cws.cfg.version,
        pm : cws.platformMeta,
        caps: cws.cfg.caps,
        fw: self.fw,
        ct: self.devinfo.GetConnectionType()
    }
    if self.moduleName <> invalid
      self.hb.cc = {}
      self.hb.cc.mn = self.moduleName
    end if
    self.psm.connType = self.hb.ct

    if sessionType = self.cws.SESSION_TYPE.AD
        self.hb.ad = true
    end if

    ' DE-2710: fw is added to pm as well as at HB level
    if self.hb.pm <> invalid
        self.hb.pm.fw = self.fw
    end if

    vid = contentInfo.viewerId
    if (type(vid)="String" or type(vid)="roString") and vid <> "" then
        self.hb.vid = vid
    end if

    ' PD-7686: add "pn" field to heartbeat
    pn = contentInfo.playerName
    if (type(pn)="String" or type(pn)="roString") and pn <> "" then
        self.hb.pn = pn
    end if

    ' DE-2710: Add tags to hb only when count > 0
    tags = contentInfo.tags
    if tags <> invalid and type(tags) = "roAssociativeArray" and tags.count() > 0 then
        self.hb.tags = tags
    end if

    self.hb.st = 0
    self.hb.pj = false
    self.hb.sst = self.sessionStartTimeMs ' PD-15624: add "sst" field
    ' PD-10341: add "lv" field to heartbeat
    if self.global = false
        if contentInfo.assetName <> invalid and contentInfo.assetName <> ""
            self.hb.an = contentInfo.assetName
        else
            self.utils.log("Missing asset name during session creation")
        end if

        lv = contentInfo.isLive
        if type(lv)="roBoolean" or type(lv)="Boolean" then
            self.hb.lv = lv
        else if lv = invalid
            self.utils.log("Missing isLive during session creation")
        end if

        ' PD-10673: add "cl" field to heartbeat
        cl = contentInfo.contentLength
        if type(cl)="roInteger" or type(cl)="roInt" or type(cl)="Integer" then
            self.hb.cl = cl
        else if cl = invalid
            self.utils.log("Missing contentLength during session creation")
        end if

        if contentInfo.streamUrls <> invalid and contentInfo.streamUrls.count() > 0
            self.psm.streamUrl = contentInfo.streamUrls[0]
        else if contentInfo.streamUrl <> invalid
            self.psm.streamUrl = contentInfo.streamUrl
        end if
        if self.psm.streamUrl = invalid
            self.utils.log("Missing streamUrl during session creation")
        end if


        if contentInfo.encodedFramerate <> invalid and (type(contentInfo.encodedFramerate)="roInteger" or type(contentInfo.encodedFramerate)= "roInt" or type(contentInfo.encodedFramerate)= "Integer") then
            self.psm.encodedFramerate = contentInfo.encodedFramerate
        else
            self.utils.log("Missing encodedFrameRate during session creation")
        end if
    end if

    self.cleanup  = function () as void
        self = m
        if self.utils = invalid then
            return
        end if

        ' Schedule a last heartbeat
        ' TODO: do we need to wait for the HB to be sent ?
        self.utils.log("Sending the last HB")
        evt = {
            t: "CwsSessionEndEvent"
        }
        self.cwsSessSendEvent(evt.t, evt)
        ' DE-5057: Differentiating last HB from Content Session to exit livepass gracefully
        if self.sessionType = self.cws.SESSION_TYPE.CONTENT
            self.cwsSessSendHb(true)
        else
            self.cwsSessSendHb(false)
        end if

        self.utils.cleanupTimer(self.hbTimer)
        self.utils.cleanupTimer(self.cdnTimer)
        self.hbTimer = invalid
        self.cdnTimer = invalid
        self.initialTimer = invalid
        self.psm.cleanup ()
        self.cws = invalid
        self.sessionId = invalid
        self.sessionTimer = invalid
        self.psm = invalid
        self.hb = invalid
        self.devinfo = invalid
        self.utils = invalid
        self.screen = invalid
        self.video = invalid
        'CSR-1967
        self.positionHeadCheck = 0
    end function

    ' We use a per-session logger, as per the CWS logging spec
    self.log = function (msg) as void
        self = m
        if self.utils = invalid then
            'print "ERROR: logging after cleanup: "+msg
            return
        end if
        if self.sessionId <> invalid then
            self.utils.log("sid="+stri(self.sessionId)+" "+msg)
        else
            self.utils.log(msg)
        end if
    end function

    self.updateMeasurements = function () as void
        self = m
        'Supress HB if its a global session
        sessionTimeMs = self.cwsSessTimeSinceSessionStart()
        self.hb.st = sessionTimeMs

        if self.global = false

            pm = self.psm.cwsPsmGetPlayerMeasurements(sessionTimeMs)
            for each st in pm
                if st = "tags"
                    if self.hb.tags = invalid
                        self.hb.tags = {}
                    end if
                    for each tk in pm.tags
                        self.hb.tags[tk] = pm.tags[tk]
                    end for
                else
                    self.hb[st] = pm[st]
                end if
            end for
            ' DE-2710: pht is added only when >= 0
            if self.pht >= 0
                self.hb.pht = self.pht * 1000 ' pht should be reported in ms
            end if
            self.hb.pj = self.pj
            if self.cws.sendLogs then
                self.hb.lg = self.utils.getLogs ()
            else
                if self.hb.lg <> invalid then
                    self.hb.delete("lg")
                end if
           end if
           ' Remove csi field from HB if collection is disabled'
           if pm["csi"] = Invalid
             self.hb.delete("csi")
           end if
        end if
        self.hb.clid = self.cws.clId
    end function

    self.setCurrentStreamInfo = function (bitrateKbps as dynamic, resource as dynamic)
        self = m
        if bitrateKbps <> -1 then
            self.psm.bitrateKbps = bitrateKbps
        end if
        if resource <> invalid then
            self.psm.resource = resource
        end if
    end function

    self.buildInitialStateChangeEvent = function (metadata as object)
        self = m
        evt = {
            t: "CwsStateChangeEvent",
            new: {}
        }
        if metadata.contentLength <> invalid then
            evt.new.cl = metadata.contentLength
        end if
        if metadata.streamUrls <> invalid and metadata.streamUrls.count() > 0
            evt.new.url = metadata.streamUrls[0]
        else if metadata.streamUrl <> invalid then
            evt.new.url = metadata.streamUrl
        end if

        if metadata.encodedFramerate <> invalid
            evt.new.efps = metadata.encodedFramerate
        end if
        if metadata.assetName <> invalid
            evt.new.an = metadata.assetName
        end if
        if metadata.isLive <> invalid
            evt.new.lv = metadata.isLive
        end if

        if metadata.defaultReportingResource <> invalid then
            evt.new.rs = metadata.defaultReportingResource
        end if

        if metadata.playerName <> invalid
            evt.new.pn = metadata.playerName
        end if

        if metadata.viewerId <> invalid
            evt.new.vid = metadata.viewerId
        end if

        ' Below mentioned have to be merged with existing data and can only be set from application
        if metadata.tags <> invalid and metadata.tags.count() > 0
            evt.new.tags = {}
            for each tk in metadata.tags
                evt.new.tags[tk] = metadata.tags[tk]
            end for
        end if
        if self.devinfo <> invalid
          evt.new.ct = self.devinfo.GetConnectionType()
        end if

        if evt <> invalid and evt.new.count() > 0 then ' sendCWSStateChangeEvent only if atleast one item is changed
            self.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    self.updateContentMetadata = function (metadata as object)
        self = m
        evt = {
            t: "CwsStateChangeEvent",
            new: {},
            old: {}
        }

        ' Below mentioned can be set from application or auto detected
        if metadata.contentLength <> invalid then
            ' DE-2710: Ensured that old values are added only when there is a change in metadata
            if self.contentInfo.contentLength <> invalid
                cl = self.contentInfo.contentLength
            else
                cl = self.psm.contentLength
            end if
            if cl <> metadata.contentLength
                if cl <> invalid and cl <> -1
                    evt.old.cl = cl
                end if
                self.psm.contentLength = metadata.contentLength
                self.contentInfo.contentLength = metadata.contentLength
                evt.new.cl = metadata.contentLength
            end if
        end if
        if metadata.streamUrl <> invalid then
            if self.contentInfo.streamUrl <> invalid
                url = self.contentInfo.streamUrl
            else
                url = self.psm.streamUrl
            end if
            if metadata.streamUrl <> url
                if url <> invalid
                    evt.old.url = url
                end if
                self.psm.streamUrl = metadata.streamUrl
                self.contentInfo.streamUrl = metadata.streamUrl
                evt.new.url = metadata.streamUrl
            end if
        end if

        ' Below mentioned can only be set from application
        if metadata.encodedFramerate <> invalid and metadata.encodedFramerate <> self.contentInfo.encodedFramerate then
            if self.contentInfo.encodedFramerate <> invalid
                evt.old.efps = self.contentInfo.encodedFramerate
            end if
            self.psm.encodedFramerate = metadata.encodedFramerate
            self.contentInfo.encodedFramerate = metadata.encodedFramerate
            evt.new.efps = metadata.encodedFramerate
        end if
        if metadata.assetName <> invalid and metadata.assetName <> self.contentInfo.assetName then
            if self.contentInfo.assetName <> invalid
                evt.old.an = self.contentInfo.assetName
            end if
            self.psm.assetName = metadata.assetName
            self.contentInfo.assetName = metadata.assetName
            evt.new.an = metadata.assetName
        end if
        if metadata.isLive <> invalid and metadata.isLive <> self.contentInfo.isLive then
            if self.contentInfo.isLive <> invalid
                evt.old.lv = self.contentInfo.isLive
            end if
            self.psm.isLive = metadata.isLive
            self.contentInfo.isLive = metadata.isLive
            evt.new.lv = metadata.isLive
        end if

        if metadata.defaultReportingResource <> invalid then
            if metadata.defaultReportingResource <> self.contentInfo.defaultReportingResource
                if self.contentInfo.defaultReportingResource <> invalid
                    evt.old.rs = self.contentInfo.defaultReportingResource
                end if
                self.psm.defaultReportingResource = metadata.defaultReportingResource
                self.contentInfo.defaultReportingResource = metadata.defaultReportingResource
                evt.new.rs = metadata.defaultReportingResource
            end if
        end if

        if metadata.playerName <> invalid and metadata.playerName <> self.contentInfo.playerName then
            if self.contentInfo.playerName <> invalid
                evt.old.pn = self.contentInfo.playerName
            end if
            self.psm.playerName = metadata.playerName
            self.contentInfo.playerName = metadata.playerName
            evt.new.pn = metadata.playerName
        end if

        if metadata.viewerId <> invalid and metadata.viewerId <> self.contentInfo.viewerId then
            if self.contentInfo.viewerId <> invalid
                evt.old.vid = self.contentInfo.viewerId
            end if
            self.psm.viewerId = metadata.viewerId
            self.contentInfo.viewerId = metadata.viewerId
            evt.new.vid = metadata.viewerId
        end if

        ' Below mentioned have to be merged with existing data and can only be set from application
        if metadata.tags <> invalid then
            oldTags = {}
            newTags = {}
            ' correct the improper values
            for each tk in metadata.tags
                if metadata.tags[tk] = invalid then
                    metadata.tags[tk] = "null"
                end if
                newTags[tk] = metadata.tags[tk]
                ' Insert into old tag only if new tag has different value
                if (self.contentInfo.tags[tk] <> invalid)
                    ' DE-4651: compare tags only when they are of same type
                    if type(self.contentInfo.tags[tk]) = type(newTags[tk])
                        if self.contentInfo.tags[tk] <> newTags[tk]
                            oldTags[tk] = self.contentInfo.tags[tk]
                            self.contentInfo.tags[tk] = newTags[tk]
                            self.psm.tags[tk] = newTags[tk]
                        ' Unchanged value - Delete from list
                        else
                            newTags.delete(tk)
                        end if
                    ' Both the value types are different, don't compare directly add to new/old
                    else
                        oldTags[tk] = self.contentInfo.tags[tk]
                        self.contentInfo.tags[tk] = newTags[tk]
                        self.psm.tags[tk] = newTags[tk]
                    end if
                ' New key - Append to existing tags
                else if (self.contentInfo.tags[tk] = invalid)
                    self.contentInfo.tags[tk] = newTags[tk]
                    self.psm.tags[tk] = newTags[tk]
                end if
            end for

            if newTags.count() > 0
                if oldTags.count() > 0
                    evt.old.tags = oldTags
                end if
                evt.new.tags = {}
                for each tk in newTags
                    evt.new.tags[tk] = newTags[tk]
                end for
            end if
        end if

        if evt <> invalid and evt.new.count() > 0 then ' sendCWSStateChangeEvent only if atleast one item is changed
            if evt.old.count() = 0
                evt.delete("old")
            end if
            self.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    self.cwsHbFailure = function (sess as dynamic, selectionTimedout as boolean, reason as string) as void
        if sess = invalid or sess.cws = invalid then
            return
        end if

        sess.log("CwsHbFailure  reason: "+ reason)

        for each hbinfo in sess.hbinfos
            if hbinfo.seq = sess.hb.seq - 1  then
                hbinfo.err = reason
            end if
        end for

    end function

    self.cwsSessSendHb = function (lastHeartbeatContentSession as boolean) as object
        sess = m
        ' DE-2710: If this is a global session, with no events, suppress this HB
        ' Do this check before we consume the logs, or increase the heartbeatSequenceNumber
        if (sess.global = true and sess.evs.count() = 0)
            return invalid
        end if
        if sess = invalid or sess.cws = invalid then
            sess.cwsHbFailure(sess, false, "session is invalid")
            return invalid
        else if sess.cws.clId = invalid then
            sess.cwsHbFailure(sess, false, "no clientid")
            sess.log("Suppress HB sending: no clientId")
            return invalid
        else if sess.cws.clId = "0" then
            sess.log("Sending HB with clientId=0")
        end if

        ' include heartbeat specific info
        index = -1
        maxseq = sess.hb.seq - sess.cfg.maxhbinfos
        if sess.cfg.maxhbinfos > 0 then

            if sess.hbinfos <> invalid and sess.hbinfos.count() > 0
                sess.hb.hbinfos = []
                for each hbinfo in sess.hbinfos
                    index = index + 1
                    'make sure the heartbeat count does not exceed maxhbinfo
                    if maxseq > hbinfo.seq then
                        if sess.hbinfos.delete(index) <> true
                            sess.log("send: unable to delete "+ str(index))
                        else
                            index = index - 1
                        end if
                    else
                        srtt = hbinfo.rtt
                        if hbinfo.err = "pending"
                            srtt = -1
                        else if hbinfo.err <> "ok"
                            srtt = 0
                        else if hbinfo.err = "ok"
                            if sess.hbinfos.delete(index) <> true
                                sess.log("sendx: unable to delete "+ str(index))
                            else
                                index = index - 1
                            end if
                        end if
                        sess.hb.hbinfos.push({seq:hbinfo.seq, rtt: srtt, err: hbinfo.err})
                     end if
                end for
            end if
        end if

        sess.updateMeasurements()

        callback = function (sess as object, success as boolean, resp as string)
            if success <> true then
                sess.cwsHbFailure(sess, false,  "Hb response failed")
            end if
            sess.cwsOnResponse(resp)
        end function

        hbTimeoutCallback = function (sess as dynamic)
            if sess.isReady <> true then
                sess.log( "hbTimeoutCallback timeout callback")
                sess.cwsHbFailure(sess, true, "hb timed out")
            end if
        end function

        sess.lastRequestSent = CreateObject("roDateTime")
        genHb = sess.cwsSessGetHb()
        sess.utils.sendPostRequest(sess.utils.convivaSettings.gatewayUrl+sess.utils.convivaSettings.gatewayPath, genHb, callback, sess, lastHeartbeatContentSession)
        sess.hbinfos.Push({seq:sess.hb.seq-1, rtt: sess.timer.TotalMilliseconds(), err: "pending"})

    end function

    self.cwsOnResponse = function (resp_txt as string) as void
        self = m
        selectionAvailable = false
        receivedTime = CreateObject("roDateTime")
        self.log("response "+ resp_txt)

        if self.cws = invalid then
            'self.cwsHbFailure(self,  false, "Received response from WSG after the session was cleaned")
            'print ("WARNING: Received response from WSG after the session was cleaned")
            return
        end if

        'resp = self.utils.jsonDecode(resp_txt)
        if self.utils <> invalid and self.utils.isJSON(resp_txt) = true then
            resp = ParseJson(resp_txt)
        end if

'        if resp = invalid or resp.err <> "ok" then
        if type(resp) = "<uninitialized>" or resp = invalid then
            msg = "empty response"
            self.cwsHbFailure(self, false, msg)
            self.log("ERROR response from gateway: "+resp_txt)
            return
        end if

        if resp.err <> invalid and resp.err <> "ok" then
            msg = resp.err
            self.cwsHbFailure(self, false, msg)
            self.log("ERROR response from gateway: "+resp_txt)
        end if

        if resp.sid=invalid or resp.clid=invalid or resp.clid="" then
            ' DE-5147: Just log error if sid/clid is missing
            'self.cwsHbFailure(self, false, "Malformed http reply")
            self.log("Malformed http reply")
            'return
        end if

        if self.sessionId <> int(resp.sid) then
            ' DE-5147: Just log error if sid in response is different from the sessionId
            'self.cwsHbFailure(self, false, "Invalid session")
            self.log("Got response for session: "+str(resp.sid)+" while in session: "+stri(self.sessionId))
            'return
        end if

        'todo do we really want to ignore out of order heartbeats
        if self.hb.seq - 1 <> resp.seq then
            'self.cwsHbFailure(self, false, "old heartbeat")
            self.log("Got old hb? "+stri(resp.seq)+" while last sent was "+stri(self.hb.seq-1))
            'return
        end if

        if resp.clid <> invalid and self.cws.clId <> resp.clid then
        'if self.cws.clId = "0" and resp.clid <> invalid then
            self.utils.log("Received clientId from server "+resp.clid)
            self.cws.clId = resp.clid
            self.utils.writeLocalData("clientId", resp.clid)
        end if

        if resp.slg = invalid then
            self.cws.sendLogs = false
        else
            self.cws.sendLogs = resp.slg
        end if

        if resp.cfg <> invalid and resp.cfg.hbi <> invalid and resp.cfg.hbi >= 1 and self.cws.cfg.heartbeatIntervalMs <>  resp.cfg.hbi * 1000 then
            self.log("Received hbInterval from server "+stri(resp.cfg.hbi))
            self.cws.cfg.heartbeatIntervalMs = resp.cfg.hbi * 1000
            self.utils.updateTimerInterval(self.hbTimer, resp.cfg.hbi * 1000)
        end if

        if resp.cfg <> invalid and resp.cfg.gw <> invalid and self.cws.cfg.gatewayUrl <> resp.cfg.gw then
            self.log("Received gatewayUrl from server "+resp.cfg.gw)
            self.cws.cfg.gatewayUrl = resp.cfg.gw
        end if

        if resp.cfg <> invalid and resp.cfg.slg <> invalid and self.cws.sendLogs <> resp.cfg.slg then
            self.cws.sendLogs = resp.cfg.slg
        end if

        if resp.cfg <> invalid  and resp.cfg.DoesExist("maxhbinfos") and self.cfg.maxhbinfos <> resp.cfg.maxhbinfos then
            self.cfg.maxhbinfos = resp.cfg.maxhbinfos
            self.log("Received maxhbinfos from backend "+ stri(resp.cfg.maxhbinfos))
        end if

        ' Update default saved configuration with updated setting from backend for CDN Server IP collection'
        if resp.cfg <> invalid  and resp.cfg.DoesExist("csi_en") and self.cfg.csi_en <> resp.cfg.csi_en then
            if self.cfg.csi_en = true and resp.cfg.csi_en = false
                self.cwsSessOnCDNServerIP("null", false)
            end if
            self.cfg.csi_en = resp.cfg.csi_en
            'self.log("Received csi_en from backend "+ resp.cfg.csi_en)
        end if

        'todo compute the rtt for the right heart beat sequence message
        self.lastResponseTimeMs = (receivedTime.asSeconds() - self.lastRequestSent.asSeconds()) * 1000 + (receivedTime.GetMilliseconds() - self.lastRequestSent.GetMilliseconds ())

        ' remove heartbeats which have a sequence number less than the current sequence number
        match = invalid
        index = -1
        for each hbinfo in self.hbinfos
            index = index + 1
            if (hbinfo.seq + self.cfg.maxhbinfos) < resp.seq
                if self.hbinfos.delete(index) <> true
                    self.log("unable to delete "+ str(index))
                else
                    index = index-1
                end if
            end if
            if hbinfo.seq = resp.seq
                reqSendTimeMs = hbinfo.rtt
                hbinfo.rtt = self.timer.TotalMilliseconds() - reqSendTimeMs
                hbinfo.err = "ok"
            end if
        end for
    end function

    self.cwsSessGetHb = function () as string
        self = m
        'Return HB data for a session as a json string
        encStart = self.sessionTimer.TotalMilliseconds()
        ' DE-2710: Add evs to hb only when count > 0
        if self.evs.count() > 0
            self.hb.evs = self.evs
        end if
        'json_data = self.utils.jsonEncode(self.hb)
        json_data = FormatJson(self.hb)

        if self.utils.convivaSettings.printHb then
            ' Do not even think of using self.log here, because then we end up with exponential HBs if sendLogs is turned on
            print "CWS: JSON: "+json_data
        end if
        ' self.log("Json encoding took "+stri(self.sessionTimer.TotalMilliseconds() - encStart)+"ms")
        ' The following line helps debugging and is also used by Touchstone to better estimate clock skew
        ' We want to put this line as late as possible before sending the HB
        self.log("Send HB["+stri(self.hb.seq)+"]")
        'Start next HB
        self.hb.seq = self.hb.seq + 1
        ' DE-2710: Delete the evs from hb after json_data is prepared and clear the local copy
        self.hb.Delete("evs")
        self.evs = []
        self.hb.Delete("hbinfos")

        return json_data
    end function

    self.cwsSessTimeSinceSessionStart = function () as integer
        self = m
        return self.sessionTimer.TotalMilliseconds()
    end function

    self.cwsSessSendEvent = function (evtType as string, evtData as object) as void
        self = m
        evtData.t = evtType
        evtData.st = self.cwsSessTimeSinceSessionStart()
        evtData.seq = self.eventSeqNumber
        ' DE-2710: Add bl and pht only when >= 0
        if self.bl >= 0
            evtData.bl = self.bl
        end if
        if self.pht >= 0
            evtData.pht = self.pht * 1000 ' pht is reported in ms
        end if
        self.eventSeqNumber = self.eventSeqNumber + 1
        self.evs.push(evtData)
    end function

    self.cwsSessionOnError = function (data as dynamic) as void
        self = m
        evt = {
            t: "CwsErrorEvent",
            ft: data.ft,
            err: data.err
        }
        self.cwsSessSendEvent(evt.t, evt)

    end function

    self.cwsSessOnStateChange = function (playerState as string, data as dynamic) as void
        self = m

        if self = invalid then
            self.log("Cannot change state for invalid session")
            return
        end if

        evt = self.psm.cwsPsmOnStateChange(self.cwsSessTimeSinceSessionStart(), playerState)
        if evt <> invalid then
            self.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    self.cwsSessOnConnectionTypeChange = function (connType as string) as void
        self = m

        if self = invalid then
            self.log("Cannot change connection type for invalid session")
            return
        end if

        evt = self.psm.cwsPsmOnConnectionTypeChange(connType)
        if evt <> invalid then
            self.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    self.cwsSessOnBitrateChange = function (newBitrateKbps as integer, externalReported as boolean) as void
        self = m
        'self.log("cwsSessOnBitrateChange "+stri(newBitrateKbps))
        if self = invalid then
            print("Cannot change bitrate for invalid session")
            return
        end if

        if externalReported = false and self.externalBitrateReporting = true then
            self.log("ERROR: Auto dectection of the Bitrate is not allowed as the externalBitrateReporting is set")
            return
        end if

        ' DE-4668: Invalid State change is requested if newBitrateKbps = -1'
        if newBitrateKbps <= 0 then
            self.log("Invalid bitrate change requested")
            return
        end if
        evt = self.psm.cwsPsmOnBitrateChange(self.cwsSessTimeSinceSessionStart(), newBitrateKbps)
        if evt <> invalid then
            if externalReported
                self.log("Bitrate change requested from the application")
            else
                self.log("Bitrate change requested from the Conviva Library")
            end if
            self.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    self.cwsSessOnDurationChange = function (contentLength as integer) as void
        self = m
        'self.log("cwsSessOnDurationChange "+stri(contentLength))
        if self = invalid then
            self.log("Cannot change contentLength for invalid session")
            return
        end if
        if contentLength = self.psm.contentLength then
            return
        end if
        evt = self.psm.cwsPsmOnDurationChange(contentLength, self.contentInfo)
        if evt <> invalid then
            self.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    self.cwsSessOnVideoResolutionChange = function (width as integer, height as integer) as void
        self = m
        if self = invalid then
            self.log("Cannot change video resolution for invalid session")
            return
        end if
        if width = self.psm.videowidth and height = self.psm.videoheight then
            return
        end if
        evt = self.psm.cwsPsmOnVideoResolutionChange(width, height)
        if evt <> invalid then
            self.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    self.cwsSessOnResourceChange = function (newStreamUrl as dynamic) as void
        self = m
        self.log("cwsSessOnResourceChange "+ newStreamUrl)
        if self = invalid then
            self.log("Cannot change resource for invalid session")
            return
        end if

        if newStreamUrl = self.psm.streamUrl then
            return
        end if
        'self.psm.streamUrl = newStreamUrl
        evt = self.psm.cwsPsmOnStreamUrlChange(self.cwsSessTimeSinceSessionStart(), newStreamUrl, self.contentInfo)
        if evt <> invalid then
            self.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    self.cwsSessOnPlayerSeekStart = function (seekToPos as integer) as void
        self = m
        self.log("cwsSessOnPlayerSeekStart "+ str(seekToPos))
        if self = invalid then
            self.log("Cannot trigger seek start for invalid session")
            return
        end if

        evt = {
            t: "CwsSeekEvent",
            act: "pss"
        }
        if seekToPos >= 0
            evt.skto = seekToPos
        end if
        self.cwsSessSendEvent(evt.t, evt)
    end function

    self.cwsSessOnPlayerSeekEnd = function () as void
        self = m
        self.log("cwsSessOnPlayerSeekEnd")
        if self = invalid then
            self.log("Cannot trigger seek end for invalid session")
            return
        end if

        evt = {
            t: "CwsSeekEvent",
            act: "pse"
        }
        self.cwsSessSendEvent(evt.t, evt)
    end function

    self.cwsSessOnCDNServerIP = function (cdnServerIP as string, externalReported as boolean) as void
        self = m
        self.log("cwsSessOnCDNServerIP")
        if self = invalid then
            self.log("Cannot set CDN server IP for invalid session")
            return
        end if

        if externalReported = false and self.externalCdnServerIpReporting = true then
            self.log("ERROR: Auto dectection of the CDN Server IP is not allowed as the externalCdnServerIpReporting is set to true")
            return
        end if

        evt = self.psm.cwsPsmOnCDNServerIPChange(cdnServerIP)
        if evt <> invalid then
            self.cwsSessSendEvent(evt.t, evt)
        end if
    end function

    ' PD-8962: Smooth Streaming support
    self.updateBitrateFromEventInfo = function (streamUrl as string, streamBitrate as integer, sequence as integer, segTypeReceived as dynamic) as void
        self = m
        if self.streamFormat = "ism" or self.streamFormat = "dash" or self.streamFormat = "hls" then
            if segTypeReceived <> invalid
                segType = segTypeReceived
            else if self.utils.downloadSegments <> invalid and self.utils.downloadSegments.Count() > 0
                segType = self.utils.getSegTypeFromSegInfo(streamUrl, sequence)
            end if


            ' DE-5147: Bitrate calculation for HLS Demuxed stream gives segType as 0 for video
            ' considering 0/2 for video segment types
            if segType = 0 or segType = 1 or segType = 2 then
                ' Fix for CSR-2196. Removing dependency on sequences
                if self.utils.videoFragmentSupported = invalid
                    self.videoBitrate = 0
                end if
                if self.utils.audioFragmentSupported = invalid
                     self.audioBitrate = 0
                end if
                if segType = 1 then
                    if self.audioBitrate <> streamBitrate then
                        self.audioBitrate = streamBitrate
                        self.log("updateBitrateFromEventInfo(): HLS / Dash / Smooth Streaming audio chunk, bitrate: " + stri(self.audioBitrate))
                    end if
                else if segType = 0 or segType = 2 then
                    ' DE-5147: Bitrate calculation for HLS Demuxed stream gives segType as 0 for video
                    ' considering 0/2 for video segment types
                    if self.videoBitrate <> streamBitrate then
                        self.videoBitrate = streamBitrate
                        self.log("updateBitrateFromEventInfo(): HLS / Dash / Smooth Streaming video chunk, bitrate: " + stri(self.videoBitrate))
                    end if
                end if

                ' Removing the deleting of the segments as ad sessions were not auto detecting bitrates'
                'self.utils.deleteSegmentsFromSegInfo(sequence, segType)

                if (self.videoBitrate <> -1 or self.utils.videoFragmentSupported = invalid) and (self.audioBitrate <> -1 or self.utils.audioFragmentSupported = invalid) then
                    ' Only report bitrate after we know both audio and video bitrate
                    if self.totalBitrate <> self.audioBitrate + self.videoBitrate then
                        self.totalBitrate = self.audioBitrate + self.videoBitrate
                        self.log("New bitrate ("+self.streamFormat+"): "+stri(self.totalBitrate))
                    end if
                end if
            else
                self.log("updateBitrateFromEventInfo(): unknown segment type, bitrate: " + stri(streamBitrate))
                ' Choosing not to do anything with it, could take a guess based on bitrate
                ' < 200 for audio >= 200 for video or something
            end if
        end if
    end function

    '
    ' Process a screen and node events of Roku Scene Graph
    '
    self.cwsProcessSceneGraphVideoEvent = function (convivaSceneGraphVideoEvent)
        self = m
        if type(convivaSceneGraphVideoEvent) = "roSGScreenEvent"
            if convivaSceneGraphVideoEvent.isScreenClosed() then               'real end of session
                self.cwsSessOnStateChange(self.ps.stopped, invalid)
            end if
        else if type(convivaSceneGraphVideoEvent) = "roSGNodeEvent"
            self.cwsSessOnConnectionTypeChange(self.devinfo.GetConnectionType())
            info = convivaSceneGraphVideoEvent.getData()
            if convivaSceneGraphVideoEvent.getField() = "streamInfo"
                if info.isResume and info.isUnderrun
                    self.log("videoEvent: streamInfo isResume=true;isUnderrun=true;measuredBitrate="+stri(info.measuredBitrate)+";streamBitrate="+stri(info.streamBitrate)+";streamUrl="+info.streamUrl)
                else if info.isResume and info.isUnderrun = false
                    self.log("videoEvent: streamInfo isResume=true;isUnderrun=false;measuredBitrate="+stri(info.measuredBitrate)+";streamBitrate="+stri(info.streamBitrate)+";streamUrl="+info.streamUrl)
                else if info.isResume = false and info.isUnderrun
                    self.log("videoEvent: streamInfo isResume=false;isUnderrun=true;measuredBitrate="+stri(info.measuredBitrate)+";streamBitrate="+stri(info.streamBitrate)+";streamUrl="+info.streamUrl)
                else
                    self.log("videoEvent: streamInfo isResume=false;isUnderrun=false;measuredBitrate="+stri(info.measuredBitrate)+";streamBitrate="+stri(info.streamBitrate)+";streamUrl="+info.streamUrl)
                end if
                if self.screen = true
                    if info.isUnderrun = false and info.isResume
                        ' DE-1510: Send pse event only if isUnderRun is false and isResume is true
                        ' depicting that the buffering is due to user initiated seek
                        self.cwsSessOnPlayerSeekEnd()
                    end if
                    ' Added code to auto detect streamformat from url, if not set through contentInfo
                    if info.streamUrl <> invalid
                        if self.streamFormat = invalid then
                            self.streamFormat = self.utils.streamFormatFromUrl(info.streamUrl)
                            self.log("streamFormat (guessed): " + self.streamFormat)
                        else
                            self.log("streamFormat (from player): " + self.streamFormat)
                        end if
                        self.cwsSessOnResourceChange(info.streamUrl)
                    end if
                end if
            else if convivaSceneGraphVideoEvent.getField() = "position" Then
                self.log("videoEvent: position="+str(info))
                ' To ignore the unwanted pht timer marking after end of midroll, added check for playing
                ' DE-785: Playing State is not reported after mid stream fatal error
                if self.video <> invalid and (self.video.GetField("state") = "playing" or self.video.GetField("state") = "finished")
                    if self.screen = true
                        'CSR-1967. In Live contents are blocked and 'finished' event received but pht value was 18000.000.
                        'Ignore the "position" event which greater then PHT + 10%.
                        ' DE-5161: converting position of type Double to integer
                        if (Abs((int(info) * 1000) - (self.pht * 1000)) < self.positionHeadCheck)
                            self.cwsSessOnStateChange(self.ps.playing, invalid)
                        end if
                        self.pht = int(info)
                        ' TODO: Need to move reporting change events part of timer to cover all the scenarios in future
                    end if
                end if
            else if self.video <> invalid and convivaSceneGraphVideoEvent.getField() = "state" Then
                'state = self.video.GetField("state")
                ' DE-4905: getData() provides accurate information of state than the video.GetField("state")
                state = info
                self.log("videoEvent: state="+state)
                if self.screen = true
                    if state = "playing" Then
                        ' DE-7666 : Content Length is not set on replay of video
                        if (self.video.duration <> invalid and self.video.duration > 0)
                            self.cwsSessOnDurationChange(self.video.duration)
                        end if
                        self.cwsSessOnStateChange(self.ps.playing, invalid)
                    else if state = "paused" Then
                        self.cwsSessOnStateChange(self.ps.paused, invalid)
                    else if state = "finished" or state = "stopped" Then
                        self.cwsSessOnStateChange(self.ps.stopped, invalid)
                    else if state = "buffering" Then
                        self.cwsSessOnStateChange(self.ps.buffering, invalid)
                    else if state = "error" Then
                        self.cwsSessOnStateChange(self.ps.stopped, invalid)
                        errorCode = self.video.errorCode
                        errorMsg = self.video.errorMsg
                        errorStr = self.video.errorStr

                        errMessage = invalid

                        if errorCode <> invalid
                            errMessage = "Roku ErrorCode[" + str(errorCode) + "]"
                        end if

                        if errorStr <> invalid
                            if errMessage <> invalid
                                errMessage = errMessage + ":" + "ErrorStr[" + errorStr + "]"
                            else
                                errMessage = "Roku ErrorStr[" + errorStr + "]"
                            end if
                        end if

                        if errorMsg <> invalid
                            if errMessage <> invalid
                                errMessage = errMessage + ":" + "ErrorMsg[" + errorMsg + "]"
                            else
                                errMessage = "Roku ErrorMsg[" + errorMsg + "]"
                            end if
                        end if

                        if errMessage = invalid
                            errMessage = "Conviva Unknown Error"
                        end if

                        errData = { ft: true,
                                    err: errMessage }
                        self.cwsSessionOnError(errData)
                    end if
                end if
                return true
            else if self.video <> invalid and convivaSceneGraphVideoEvent.getField() = "duration" Then
                self.log("videoEvent: duration="+str(info))
                ' To ignore the unwanted setting video duration after end of midroll, added check for playing
                if self.video.GetField("state") = "playing"
                    ' DE-5161: converting position of type Double to integer
                    self.cwsSessOnDurationChange(int(info))
                end if
            else if convivaSceneGraphVideoEvent.getField() = "streamingSegment" Then
                if info <> invalid
                    self.log("videoEvent: streamingSegment segBitrateBps="+formatJSON(info))
                    ' updateBitrateFromEventInfo API will set proper bitrate for SS by combining Audio and Video Bitrates
                    ' DE-5167: Converting segSequence of integer type to integer returns different value
                    if self.externalBitrateReporting = false
                        self.log("videoEvent: streamingSegment segBitrateBps="+formatJSON(info))
                        if info.segType <> invalid
                            if self.utils.streamingSegmentSetTypeSupported = invalid
                                self.utils.streamingSegmentSetTypeSupported = true
                                if self.utils.downloadSegments <> invalid
                                    self.utils.downloadSegments.clear()
                                end if
                            end if
                            self.updateBitrateFromEventInfo(info.segUrl, int(info.segBitrateBps/1000), info.segSequence, info.segType)
                        else
                            self.updateBitrateFromEventInfo(info.segUrl, int(info.segBitrateBps/1000), info.segSequence, invalid)
                        end if
                        if self.screen = true
                            self.cwsSessOnBitrateChange(self.totalBitrate, false)
                        else
                            ' Restoring the prevBitrate reported during detach streamer as a fallback
                            ' even during ad playback, Roku doesn't report bitrate
                            self.prevBitrateKbps = self.totalBitrate
                        end if
                    end if

                    'Report video resolution - Roku OS 9.4 and above'
                    if info.Width <> invalid and info.Height <> invalid
                        if info.Width > 0 and info.Height > 0
                            self.cwsSessOnVideoResolutionChange(info.Width, info.Height)
                        end if
                    end if

                end if
            else if convivaSceneGraphVideoEvent.getField() = "downloadedSegment" Then
                self.log("videoEvent: downloadedSegment sequence="+stri(info.segSequence)+" SegType="+stri(info.SegType)+" SegUrl="+info.SegUrl)
                ' DE-5147: Bitrate calculation for HLS Demuxed stream gives segType as 0 for video
                ' considering 0/2 for video segment types
                if self.externalBitrateReporting = false and self.utils.streamingSegmentSetTypeSupported = invalid
                    self.log("videoEvent: downloadedSegment sequence="+stri(info.segSequence)+" SegType="+stri(info.SegType)+" SegUrl="+info.SegUrl)
                    if (self.streamFormat = "ism" or self.streamFormat = "dash" or self.streamFormat = "hls") and (info.SegType = 0 or info.SegType = 1 or info.SegType = 2) then
                        self.utils.insertDownloadSegments(info)
                    end if
                end if
                self.cdnServerStreamUrl = info.SegUrl

            end if
        end if
    end function

    ' DE-4649: Sending Initial CwsStateChangeEvent with new values during init
    if self.global = false
        self.buildInitialStateChangeEvent(contentInfo)
    end if
    self.cwsSessSendHb(false) 'Send urgent HB
    return self
end function


'-------------------------
' PlayerStateManager class
'-------------------------
function cwsConvivaPlayerState(sess as object) as object
    self = {}
    self.session = sess
    self.utils = sess.utils
    self.devinfo = sess.devinfo

    ps = sess.ps
    self.ignoreBufferingStatus = false
    self.totalBufferingEvents = 0
    self.joinTimeMs = -1
    self.contentLength = -1
    self.encodedFramerate = -1
    self.videoWidth = -1
    self.videoHeight = -1

    self.totalPlayingKbits = 0
    self.curState = self.session.ps.stopped

    self.bitrateKbps = -1
    ' DE-4650: resource is not getting updated using updateContentMetadata
    ' DE-7668: log message added if resource is not set before session creation
    if sess.contentInfo.defaultReportingResource <> invalid
        self.defaultReportingResource = sess.contentInfo.defaultReportingResource
    else
        self.utils.log("Missing resource during session creation")
    end if

    self.connType = invalid
    self.cdnServerIP = invalid
    self.tags = {}

    self.cleanup = function () as void
        self = m
        self.devinfo = invalid
        self.session = invalid
        self.utils = invalid
    end function

    self.cwsPsmOnStateChange = function (sessionTimeMs as integer, newState as string) as object
        self = m
        ps = self.session.ps
        if newState=invalid or (self.curState=newState) then
            return invalid
        end if

        self.session.cws.utils.log("STATE CHANGE FROM "+self.curState+" to "+newState)

        pst = {
            t: "CwsStateChangeEvent",
            new: {
                ps: strtoi(newState)
            }
        }
        if self.curState <> invalid then
            pst.old = {
                ps: strtoi(self.curState)
            }
        end if
        self.curState = newState

        return pst
    end function

    self.cwsPsmOnBitrateChange = function (sessionTimeMs as integer, newBitrateKbps as integer) as object
        self = m
        if self.bitrateKbps = newBitrateKbps then
            return invalid
        end if
        brc = {
            t: "CwsStateChangeEvent",
            new: {
                br: newBitrateKbps
            }
        }
        if self.bitrateKbps <> -1 then
            brc.old = {
                    br: self.bitrateKbps
            }
        end if
        self.bitrateKbps = newBitrateKbps
        return brc
    end function

    self.cwsPsmOnDurationChange = function (contentLength as integer, contentInfo as dynamic) as object
        self = m
        ' DE-1099: Added check not to allow conviva library to override the contentLength if set part of contentInfo
        if contentInfo.contentLength <> invalid or self.contentLength = contentLength or contentLength = invalid
            return invalid
        end if
        evt = {
            t: "CwsStateChangeEvent",
            new: {
                cl: contentLength
            }
        }
        ' DE-2710: Add old values only when the field is changed
        if self.contentLength <> invalid and self.contentLength <> -1
            evt.old = {
                cl: self.contentLength
            }
        end if
        self.contentLength = contentLength
        return evt
    end function

    self.cwsPsmOnVideoResolutionChange = function (width as integer, height as integer) as object
        self = m
        evt = {
            t: "CwsStateChangeEvent",
            new: {
                w: width,
                h: height
            }
        }
        if (self.videoWidth <> invalid and self.videoWidth <> -1) and (self.videoHeight <> invalid and self.videoHeight <> -1)
            evt.old = {
                w: self.videoWidth,
                h: self.videoHeight
            }
        end if
        self.videoWidth = width
        self.videoHeight = height
        return evt
    end function

    self.cwsPsmOnConnectionTypeChange = function (connType as string) as object
        self = m
        if self.connType = connType then
            return invalid
        end if

        evt = {
            t: "CwsStateChangeEvent",
            new: {
                ct: connType
            }
        }
        ' DE-2710: Add old values only when the field is changed
        if self.connType <> invalid
            evt.old = {
                ct: self.connType
            }
        end if

        self.connType = connType
        return evt
    end function

    self.cwsPsmOnStreamUrlChange = function (sessionTimeMs as integer, newUrl as dynamic, contentInfo as dynamic) as object
        self = m
        if self.streamUrl = newUrl
            return invalid
        end if
        ' DE-1119: Giving preference to contentInfo set from application over autodetection
        if contentInfo.streamUrls = invalid and contentInfo.streamUrl = invalid and newUrl <> invalid
            evt = {
                t: "CwsStateChangeEvent",
                new: {
                    url: newUrl
                }
            }
            ' DE-2710: Add old values only when the field is changed
            if self.streamUrl <> invalid
                evt.old = {
                    url: self.streamUrl
                }
            end if
            self.streamUrl = newUrl
            return evt
        else
            return invalid
        end if

    end function

    self.cwsPsmOnCDNServerIPChange = function (newCDNServerIP as string) as object
        self = m
        if self.cdnServerIP = newCDNServerIP then
            return invalid
        end if
        if (type(newCDNServerIP) = "roString" or type(newCDNServerIP) = "String") and newCDNServerIP <> "" then
            cdnc = {
                t: "CwsStateChangeEvent",
                new: {
                    csi: newCDNServerIP
                }
            }
            if self.cdnServerIP <> "" and self.cdnServerIP <> invalid then
                cdnc.old = {
                    csi: self.cdnServerIP
                }
            end if
            self.cdnServerIP = newCDNServerIP
            return cdnc
        else
            return invalid
        end if
    end function


    self.cwsPsmGetPlayerMeasurements = function (sessionTimeMs as integer) as object
        self = m
        data = {
            ps: strtoi(self.curState)
        }
        ' DE-4650: resource is not getting updated using updateContentMetadata
        if self.defaultReportingResource <> invalid
            data.rs = self.defaultReportingResource
        end if

        if self.streamUrl <> invalid
            data.url =  self.streamUrl
        end if

        if self.bitrateKbps <> -1
            data.br =  self.bitrateKbps
        else if self.session.totalBitrate <> -1
            data.br = self.session.totalBitrate
        end if

        if self.encodedFramerate <> -1 then
            data.efps = self.encodedFramerate
        end if

        if self.contentLength <> -1 then
            data.cl = self.contentLength
        end if

        if self.videoWidth <> -1 then
            data.w = self.videoWidth
        end if

        if self.videoHeight <> -1 then
            data.h = self.videoHeight
        end if

        if self.playerName <> invalid
            data.pn = self.playerName
        end if

        if self.isLive <> invalid
            data.lv = self.isLive
        end if
        if self.assetName <> invalid
            data.an =  self.assetName
        end if
        ' DE-2710: Add tags to hb only when the count > 0
        if self.tags <> invalid and self.tags.count() > 0
            data.tags =  self.tags
        end if
        if self.viewerId <> invalid
            data.vid = self.viewerId
        end if
        if self.session.fw <> invalid
            data.fw = self.session.fw
        end if
        if self.connType <> invalid
            data.ct = self.connType
        end if
        ' Send CDN Server IP info only if it is enabled in config
        if self.cdnServerIP <> invalid and self.cdnServerIP <> "null"
            data.csi = self.cdnServerIP
        else if self.cdnServerIP = "null"
            data.delete("csi")
        end if

        return data
    end function

    return self
end function

' Copyright: Conviva Inc. 2011-2012
' Conviva LivePass Brightscript Client library for Roku devices
' LivePass Version: 3.0.15
' authors: Alex Roitman <shura@conviva.com>
'          George Necula <necula@conviva.com>
'

''''
'''' Utilities
''''
' A series of methods used to access the platform services
' This function will construct a singleton object with the platform utilities.
' For each call to ConvivaUtils() there should be a call to utils.cleanup ()
function cwsConvivaUtils()  as object
    ' We only want a single Utils object around
    globalAA = GetGlobalAA()
    self = globalAA.cwsConvivaUtils
    if self <> invalid then
        self.refcount = 1 + self.refcount
        return self
    end if
    self  = { }
    self.refcount = 1     ' Since the utilities may be shared across modules, we keep a reference count
                          ' to know when we need to really clean up
    globalAA.cwsConvivaUtils = self
    self.regexes = invalid
    self.convivaSettings = cwsConvivaSettings ()
    self.httpPort = invalid ' the PORT on which we will be listening for the HTTP responses
    self.logBuffer = [ ]   ' We keep here a list of the last few log entries
    self.logBufferMaxSize = 32
    self.downloadSegments = CreateObject("roArray", 1, true)
    self.availableUtos = [] ' A list of available UTO objects for sending POSTs
    self.pendingRequests = { } ' A map from SourceIdentity an object { uto, callback }
    self.audioFragmentSupported = invalid
    self.videoFragmentSupported = invalid
    self.streamingSegmentSetTypeSupported = invalid
    self.prevSequence = -1
    self.baseAudioSeq = -1
    self.baseVideoSeq = -1
    self.pendingTimers = { } ' A map of timers indexsed by their id : { timer (roTimespan), timerIntervalMs }
    self.nextTimerId   = 0
    self.sessionEndRequestIdentity = -1
    self.isCleanupSuccessful = false

    self.start = function ()
        ' Start the
        self = m
        self.regexes = self.cwsRegexes ()
        self.httpPort = CreateObject("roMessagePort")
        for ix = 1 to self.convivaSettings.maxUtos
            uto = CreateObject("roUrlTransfer")
            uto.SetCertificatesFile("common:/certs/ca-bundle.crt")
            uto.SetPort(self.httpPort)
            ' By default roku adds a Expect: 100-continue header. This does
            ' not work properly with the Touchstone HTTPS redirectors, and it
            ' is only an optimization, so we turn it off here.
            uto.AddHeader("Expect", "")
            self.availableUtos.push(uto)
        end for
    end function

    self.cleanup = function () as void
        self = m
        self.refcount = self.refcount - 1
        if self.refcount > 0 then
            self.log("ConvivaUtils not yet cleaning. Refcount now "+stri(self.refcount))
            return
        end if
        if self.refcount < 0 then
            print "ERROR: cleaning ConvivaUtils too many times"
            return
        end if
        self.log("Cleaning up the utilities")
        for each tid in self.pendingTimers
            self.cleanupTimer(self.pendingTimers[tid])
        end for
        self.pendingTimers.clear ()
        self.availableUtos.clear()
        if self.downloadSegments <> invalid
            self.downloadSegments.clear()
            self.downloadSegments = invalid
        end if
        self.logBuffer = invalid
        self.httpPort = invalid
        self.isCleanupSuccessful = false
        self.sessionEndRequestIdentity = -1

        GetGlobalAA().delete("cwsConvivaUtils")
    end function

    ' Time since Epoch
    ' We do not get it in ms, because that would require a float and Roku seems
    ' to use single-precision for floats
    ' We try to force it as a double
    self.epochTimeSec = function ()
        dt = CreateObject("roDateTime")
        return 0# + dt.asSeconds() + (dt.getMilliseconds () / 1000.0#)
    end function

    self.randInt = function () as integer
        return  int(2147483647*rnd(0))
    end function

     ' Log a string message
     self.log = function (msg as string) as void
            self = m
            if self.logBuffer <> invalid then
                dt = CreateObject("roDateTime")
                ' Poor's man printing of floating points
                msec = dt.getMilliseconds ()
                msecStr = stri(msec).trim()
                if msec < 10:
                    msecStr = "00" + msecStr
                else if msec < 100:
                    msecStr = "0" + msecStr
                end if
                'msg = "[" + stri(dt.asSeconds()) + "." + msecStr + "] " + msg
                ' Adding the code to print time in GMT for internal debugging purpose
                msg = "GMT:" + str(dt.GetHours())+ ":"+ str(dt.GetMinutes())+ ":"+ str(dt.GetSeconds())+ ":"+ str(dt.getMilliseconds()) +": "+ msg
                self.logBuffer.push(msg)
                if self.logBuffer.Count() > self.logBufferMaxSize then
                    self.logBuffer.Shift()
                end if
            else
                print "WARNING: called log after utils was cleaned"
            end if
            ' The enableLogging flag controls ONLY the printing to the console
            if self.convivaSettings.enableLogging then
                print "CWS: "+msg
            end if
      end function

      ' Log an error message
      self.err = function (msg as string) as void
            m.log("ERROR: "+msg)
      end function

      ' Get and consume the log buffer
      self.getLogs = function ()
        self = m
        res = self.logBuffer
        self.logBuffer = [ ]
        return res
      end function

      ' Read local data
      self.readLocalData = function (key as string) as string
          sec = CreateObject("roRegistrySection", "ConvivaPersistent")
          if sec.exists(key) then
              return sec.read(key)
          else
              return ""
          end If
       end function

       ' Write local data
       self.writeLocalData = function (key as string, value as string)
          sec = CreateObject("roRegistrySection", "ConvivaPersistent")
          sec.write(key, value)
          sec.flush()
       end function

       ' Delete local data
       self.deleteLocalData = function ( )
           sec = CreateObject("roRegistrySection", "ConvivaPersistent")
           keyList = sec.GetKeyList ()
           For Each key In keyList
               m.log("Storage : deleting "+ key)
               sec.Delete(key)
           End For
           sec.flush ()
       end Function

       ' Check the server response is in the form of JSON or not
       self.isJSON = function (value as string) as boolean
           r = CreateObject( "roRegex", "^\s*\{", "i" )
           return r.IsMatch(value)
       end function

       ' Encode JSON
       self.jsonEncode = Function (what As object) As object
          self = m
          Return self.cwsJsonEncodeDict(what)
       End Function

       ' Decode JSON
       self.jsonDecode = Function (what As String) As object
          self = m
          Return self.cwsJsonParser(what)
       End Function

       ' Send a POST request
       self.sendPostRequest = function (url As String, request as String, callback As Function, callbackObj as dynamic, lastHeartbeatContentSession as boolean) as object
           self = m

           ' See if we have an available UTO to use
           uto = self.availableUtos.pop()
           if uto = invalid
               self.err("Cannot send POST, out of UTO objects")
               return invalid
           end if

           ' Send the actual post request
           uto.SetUrl(url)
           if uto.AsyncPostFromString(request) Then
               reqId = uto.GetIdentity ()
               ' DE-5057: Store the sessionEndRequestIdentity for identifying response of session end request
               if lastHeartbeatContentSession
                   self.sessionEndRequestIdentity = reqId
               end if
               self.pendingRequests[stri(reqId)] = {
                   callback : callback,
                   callbackObj : callbackObj,
                   uto: uto
               }
               self.log("Posted request #"+stri(reqId)+" to "+url)
               l = 0
               for each item in self.pendingRequests
                   l = l + 1
               end for
               self.log("Pending requests size is"+stri(l))
           else
               self.err("POST Request failed")
               self.availableUtos.push(uto)
               return invalid
           end if
       end Function

       ' Send a POST request
       self.sendCDNRequest = function (url As String, callback As Function, callbackObj as dynamic) as object
           self = m

           ' See if we have an available UTO to use
           uto = self.availableUtos.pop()
           if uto = invalid
               self.err("Cannot send HEAD, out of UTO objects")
               return invalid
           end if

           ' Send the actual post request
           uto.SetUrl(url)

           'Hardcoding akamai headers, update method signature for final impl
           uto.AddHeader("Pragma","akamai-x-cache-on")

           if uto.AsyncHead() Then
               reqId = uto.GetIdentity ()
               self.pendingRequests[stri(reqId)] = {
                   callback : callback,
                   callbackObj : callbackObj,
                   uto: uto
               }
               self.log("Posted HEAD request #"+stri(reqId)+" to "+url)
               l = 0
               for each item in self.pendingRequests
                   l = l + 1
               end for
               self.log("Pending requests size is"+stri(l))
           else
               self.err("HEAD Request failed")
               self.availableUtos.push(uto)
               return invalid
           end if
       end Function

       ' Process a urlEvent and return true if we recognized it
       self.processUrlEvent = Function (convivaUrlEvent As object) As Boolean
           self = m
           sourceId = convivaUrlEvent.GetSourceIdentity ()
           reqData = self.pendingRequests[stri(sourceId)]
           If reqData = invalid Then
               ' We do not recognize it
               self.err("Got unrecognized response")
               Return False
           End If
           if convivaUrlEvent.GetTargetIpAddress() <> invalid
               reqData.callbackObj.targetIpAddress = convivaUrlEvent.GetTargetIpAddress()
           end if

           self.pendingRequests.delete(stri(sourceId))
           self.availableUtos.push(reqData.uto)
           respData = ""
           respCode = convivaUrlEvent.GetResponseCode()
           If respCode = 200 Then
               reqData.callback(reqData.callbackObj, True, convivaUrlEvent.GetString())
           Else
               reqData.callback(reqData.callbackObj, False, convivaUrlEvent.GetFailureReason())
           End If
      End Function

      ' Timers
      ' Too many timers will degrade performance of the main loop
      self.createTimer = Function (callback As Function, callbackObj, intervalMs As Integer, actionName As String)
          self = m
          timerData = {
              timer : CreateObject("roTimespan"),  ' Will be marked when we fire
              intervalMs : intervalMs,
              callback : callback,
              callbackObj : callbackObj,
              actionName : actionName,
              timerId : stri(self.nextTimerId),
              fireOnce : False,
              }
           timerData.timer.Mark ()
           self.pendingTimers[timerData.timerId] = timerData
           self.nextTimerId = 1 + self.nextTimerId
           Return timerData
      End Function

      ' Schedule an action after a certain number of milliseconds (one-fire timer)
      self.scheduleAction = Function(callback As Function, callbackObj as dynamic, intervalMs As Integer, actionName As String)
           self = m
           timerData = self.createTimer (callback, callbackObj, intervalMs, actionName)
           timerData.fireOnce = True
           return timerData
      End Function

      self.cleanupTimer = Function (timerData As dynamic)
          m.pendingTimers.delete(timerData.timerId)
          timerData.clear ()
      End Function

      self.updateTimerInterval = function (timerData as object, newIntervalMs as integer)
         timerData.intervalMs = newIntervalMs
      end function

      ' Find how much time until the next registered timer event
      ' While doing this, process the timer events that are due
      ' Return invalid if there is no timer
      self.timeUntilTimerEvent = Function ()
          self = m
          res  = invalid
          For Each tid in self.pendingTimers
              timerData = self.pendingTimers[tid]
              timeToNextFiring = timerData.intervalMs - timerData.timer.TotalMilliseconds ()
              If timeToNextFiring <= 0 Then
                  ' Fire the action
                  timerData.callback (timerData.callbackObj)
                  If timerData.fireOnce Then
                      ' TODO: can we change the array while iterating over it ?
                      self.pendingTimers.delete(tid)
                      timeToNextFiring = invalid
                  Else
                      timerData.timer.Mark ()
                      timeToNextFiring = timerData.intervalMs
                  End If
              End If
              if timeToNextFiring <> invalid then
                  If res = invalid then
                      res = timeToNextFiring
                  else if timeToNextFiring < res Then
                      res = timeToNextFiring
                  End If
              end if
          End For
          Return res
      End Function

      self.set = function ()
      end function

    ' A wrapper around the system's wait that will process our timers, HTTP requests, and videoEvents
    ' If it gets an event that is not private to Conviva, it will return it
    ' ConvivaObject should be the reference to the object returned by ConvivaLivePassInit
    self.wait = function (timeout as integer, port as object, customWait as dynamic, ConvivaObject as object) as dynamic
        self = m

        if timeout = 0 then
            timeoutTimer = invalid
        else
            timeoutTimer = CreateObject("roTimeSpan")
            timeoutTimer.mark()
        end if

        ' Run the event loop, return from the loop with an event that we have not processed
        while True
            convivaWaitEvent = invalid
            ' Run the ready timers, and get the time to the next timer
            timeToNextTimer = self.timeUntilTimerEvent()

            ' Perhaps we are done
            if timeout > 0 Then
                timeToExternalTimeout = timeout - timeoutTimer.TotalMilliseconds()
                If timeToExternalTimeout <= 0 Then
                    ' We reached the external timeout
                    Return invalid

                Else If timeToNextTimer = invalid or timeToExternalTimeout < timeToNextTimer Then
                    realTimeout = timeToExternalTimeout
                Else
                    realTimeout = timeToNextTimer
                End If
            Else if timeToNextTimer = invalid then
                ' Even if we have no timers, or external constraints, do not block on wait for too long
                ' We need this to ensure that we can periodically poll our private ports
                realTimeout = 100
            else
                realTimeout = timeToNextTimer
            End If

            ' Sanitize the realTimeout: range 0-100ms:
            ' We don't want to block for more than 100 ms
            if realTimeout > 100 then
                realTimeout = 100
            else if realTimeout <= 0 then
                ' This happened before because timeUntilTimerEvent returned negative value
                realTimeout = 1
            end if

            ' Wait briefly for messages on our httpPort
            httpEvent = wait(1, self.httpPort)
            if httpEvent <> invalid then
                if type(httpEvent) = "roUrlEvent" then            'Process network response
                    if not self.processUrlEvent(httpEvent) Then
                        ' This should never happen, because httpPort is private
                        if self.sessionEndRequestIdentity <> -1 and self.sessionEndRequestIdentity = httpEvent.GetSourceIdentity()
                            self.log("Last HB request is received, cleanup content session is successful")
                            self.isCleanupSuccessful = true
                            self.sessionEndRequestIdentity = -1
                        end if
                        Return httpEvent
                    End if
                end if
            end if

            'Call either real wait or custom wait function
            if customWait = invalid then
                convivaWaitEvent = wait(realTimeout, port)
            else
                convivaWaitEvent = customWait(realTimeout, port)
            end if

            if convivaWaitEvent <> invalid then   'Process player events
                if type(convivaWaitEvent) = "roSGNodeEvent" or type(convivaWaitEvent) = "roSGScreenEvent" Then
                    if ConvivaObject <> invalid and ConvivaObject.session <> invalid then
                        ConvivaObject.session.cwsProcessSceneGraphVideoEvent (convivaWaitEvent)
                        if ConvivaObject.adsession <> invalid
                          ConvivaObject.adsession.cwsProcessSceneGraphVideoEvent (convivaWaitEvent)
                        end if
                    else if type(convivaWaitEvent) = "roSGNodeEvent"
                            if convivaWaitEvent.getField() = "downloadedSegment" Then
                                info = convivaWaitEvent.getData()
                                self.log("videoEvent: isDownloadSegmentInfo sequence="+stri(info.segSequence)+" SegType="+stri(info.SegType)+" SegUrl="+info.SegUrl)
                                if (info.SegType = 0 or info.SegType = 1 or info.SegType = 2) then
                                    ' DE-5147: Bitrate calculation for HLS Demuxed stream gives segType as 0 for video
                                    ' considering 0/2 for video segment types
                                    self.insertDownloadSegments(info)
                                end if
                            end if
                    else if type(convivaWaitEvent) = "roSGScreenEvent"
                        self.log("Got "+type(convivaWaitEvent)+" convivaWaitEvent type = "+str(convivaWaitEvent.GetType()))
                    end if
                    ' We need to return the convivaWaitEvent even if we processed it
                    return convivaWaitEvent
                else if type(convivaWaitEvent) = "roUrlEvent" then
                    return convivaWaitEvent
                else
                    self.log("GOT unexpected convivaWaitEvent "+type(convivaWaitEvent))
                    'print("msg: "+convivaWaitEvent.getMessage()+" index: "+stri(convivaWaitEvent.getIndex())+" data: "+stri(convivaWaitEvent.getData()))
                    'print("Returning to caller")
                    Return convivaWaitEvent
                end if
            end if
        end while

        'Return the convivaWaitEvent to the caller of cwsWait
        return convivaWaitEvent
    end function

    '===============================
    ' Miscellaneous utility functions
    '================================
    self.cwsRegexes = function () as object
        ret = {}
        q = chr(34) 'quote
        b = chr(92) 'backslash

        'Regular expression needed for json string encoding
        ret.quote = CreateObject("roRegex", q, "i")
        ret.bslash = CreateObject("roRegex", String(2,b), "i")
        ret.bspace = CreateObject("roRegex", chr(8), "i")
        ret.tab = CreateObject("roRegex", chr(9), "i")
        ret.nline = CreateObject("roRegex", chr(10), "i")
        ret.ffeed = CreateObject("roRegex", chr(12), "i")
        ret.cret = CreateObject("roRegex", chr(13), "i")
        ret.fslash = CreateObject("roRegex", chr(47), "i")

        'Regular expression needed for parsing
        ret.cwsOpenBrace = CreateObject( "roRegex", "^\s*\{", "i" )
        ret.cwsOpenBracket = CreateObject( "roRegex", "^\s*\[", "i" )
        ret.cwsCloseBrace = CreateObject( "roRegex", "^\s*\},?", "i" )
        ret.cwsCloseBracket = CreateObject( "roRegex", "^\s*\],?", "i" )

        ret.cwsKey = CreateObject( "roRegex", "^\s*" + q + "(\w+)" + q + "\s*\:", "i" )
        ret.cwsString = CreateObject( "roRegex", "^\s*" + q + "([^" + q + "]*)" + q + "\s*,?", "i" )
        ret.cwsNumber = CreateObject( "roRegex", "^\s*(\-?\d+(\.\d+)?)\s*,?", "i" )
        ret.cwsTrue = CreateObject( "roRegex", "^\s*true\s*,?", "i" )
        ret.cwsFalse = CreateObject( "roRegex", "^\s*false\s*,?", "i" )
        ret.cwsNull = CreateObject( "roRegex", "^\s*null\s*,?", "i" )

        'This is needed to split the scheme://server part of the URL
        ret.resource = CreateObject("roRegex", "(\w+://[\w\d:#@%;$()~_\+\-=\.]+)/.*", "i")

        ' PD-8962: Smooth Streaming support
        ret.ss = CreateObject("roRegex", "\.ism", "i")
        ret.ssAudio = CreateObject("roRegex", "\/Fragments\(audio", "i")
        ret.ssVideo = CreateObject("roRegex", "\/Fragments\(video", "i")
        ret.hls = CreateObject("roRegex", "\.m3u8", "i")
        ret.dash = CreateObject("roRegex", "\.mpd", "i")

        ' PD-10716: safer handling of roVideoEvent #11, "EventStatusMessage"
        ret.videoTrackUnplayable = CreateObject("roRegex", "^(?=.*\bvideo\b)(?=.*\btrack\b)(?=.*\bunplayable\b)", "i")

        return ret
    end function

    self.getSegTypeFromSegInfo = function (streamUrl as string, sequence as integer) as integer
        self = m
        if self.downloadSegments <> invalid and self.downloadSegments.Count() > 0
            for each segInfo in self.downloadSegments
                if segInfo.Sequence = sequence and segInfo.SegUrl = streamUrl
                    return segInfo.SegType
                end if
            end for
        end if
        return -1
    end function

    self.deleteSegmentsFromSegInfo = function (sequence as integer, segType as integer)
        self = m
        ' delete the reported sequence number entries of audio/video segments based on segType
        for i = self.downloadSegments.Count()-1 to 0 Step -1
            if self.downloadSegments[i].Sequence = sequence and self.downloadSegments[i].SegType = segType
                self.downloadSegments.delete(i)
            end if
        end for
    end function

    ' PD-8962: Smooth Streaming support
    self.ssFragmentTypeFromUrl = function (streamUrl as string)
        self = m
        if self.regexes.ssAudio.IsMatch(streamUrl) then
            return "audio"
        else if self.regexes.ssVideo.IsMatch(streamUrl) then
            return "video"
        else
            return "unknown"
        end if
    end function

    ' PD-8962: Smooth Streaming support
    self.streamFormatFromUrl = function (streamUrl as string) as string
        self = m
        if self.regexes.ss.IsMatch(streamUrl) then
            return "ism"
        else if self.regexes.hls.IsMatch(streamUrl) then
            return "hls"
        else if self.regexes.dash.IsMatch(streamUrl) then
            return "dash"
        else
            return "mp4"
        end if
    end function

    self.insertDownloadSegments = function (info as object) as void
        self = m
        if self.streamingSegmentSetTypeSupported = invalid
            segFound = false
            if self.audioFragmentSupported = invalid
                if info.SegType = 1 ' audio
                    self.audioFragmentSupported = true
                    if self.baseAudioSeq = -1
                        self.baseAudioSeq = info.segSequence
                    end if
                end if
            end if
            if self.videoFragmentSupported = invalid
                if info.SegType = 2 or info.SegType = 0' video
                    ' DE-5147: Bitrate calculation for HLS Demuxed stream gives segType as 0 for video
                    ' considering 0/2 for video segment types
                    self.videoFragmentSupported = true
                    if self.baseVideoSeq = -1
                        self.baseVideoSeq = info.segSequence
                    end if
                end if
            end if
            if self.downloadSegments <> invalid
                if self.downloadSegments.Count() > 0
                    for each segInfo in self.downloadSegments
                        if segFound then exit for
                        if segInfo.Sequence = info.segSequence and segInfo.SegType = info.SegType and segInfo.SegUrl = info.SegUrl
                            segFound = true
                        end if
                    end for
                end if
                ' If segment is not found, then add to array
                if segFound = false
                    downSegInfo = CreateObject("roAssociativeArray")
                    downSegInfo.Sequence = info.segSequence
                    downSegInfo.SegType = info.SegType
                    downSegInfo.SegUrl = info.SegUrl
                    self.downloadSegments.push(downSegInfo)
                end if
            end if
        end if
    end Function
    ' PD-10716: safer handling of roVideoEvent #11, "EventStatusMessage"
    self.getEventStatusMessageType = function (message as string) as string
        self = m
        if self.regexes.videoTrackUnplayable.IsMatch(message) or message = "Content contains no playable tracks." then
            return "error"
        else if message = "Unspecified or invalid track path/url." or message = "ConnectionContext failure" then
            return "error"
        else if message = "startup progress" then
            return "buffering"
        else if message = "start of play" then
            return "playing"
        else if message = "playback stopped" or message = "end of stream" or message = "end of playlist" then
            return "stopped"
        else
            return "unknown"
        end if
    end function

    ' DE-2669: CWS Gateway URL implementation
    self.createConvivaCwsGatewayUrl = function (apiKey as string, gatewayurl as Object) as string
        self = m
        url = invalid
        if gatewayurl <> invalid
            hostNameRegex = CreateObject("roRegex", "://", "i")
            url = hostNameRegex.Split(gatewayurl)
        end if
        if gatewayurl = invalid or gatewayurl = "" or url[1] = "cws.conviva.com" or (url <> invalid and url[0] <> "https" and url[0] <> "http")
            if url <> invalid and type(url) = "roList" and url[1] = "cws.conviva.com"
                print "ERROR: Gateway URL should not be set to https://cws.conviva.com or http://cws.conviva.com, therefore this call is ignored"
            end if
            return "https://" + apiKey + "." +"cws.conviva.com"
        else
            return gatewayurl
        end if
    end function

    '================================================
    ' Utility functions for encoding and parsing JSON
    '================================================
    self.cwsJsonEncodeDict = function (dict) as string
        self = m
        ret = box("{")
        notfirst = false
        comma = ""
        q = chr(34)

        for each key in dict
            val = dict[key]
            typestr = type(val)
            if typestr="roInvalid" then
                valstr = "null"
            else if typestr="roBoolean" then
                if val then
                    valstr = "true"
                else
                    valstr = "false"
                end if
            else if typestr="roString" or typestr="String" then
                valstr = self.cwsJsonEncodeString(val)
            else if typestr="roInteger" then
                valstr = stri(val)
            else if typestr="roFloat" or typestr="Double" then
                valstr = self.cwsJsonEncodeDouble(1# * val)
            else if typestr="roArray" then
                valstr = self.cwsJsonEncodeArray(val)
            else
                valstr = self.cwsJsonEncodeDict(val)
            end if
            if notfirst then
                comma = ", "
            else
                notfirst = true
            end if
            ret.appendstring(comma,len(comma))
            ret.appendstring(q,1)
            ret.appendstring(key,len(key))
            ret.appendstring(q,1)
            ret.appendstring(": ", 2)
            ret.appendstring(valstr,len(valstr))
        end for
        return ret + "}"
    end function

    ' We write our own printer for floats, because the built-in "val" prints
    ' something like 1.2345e9, which has too little precision
    self.cwsJsonEncodeDouble = function (fval as Double) as string
        self = m
        ' print "Encoding "+str(fval)
        sign = ""
        if fval < 0 then
           sign = "-"
           fval = - fval
        end if
        ' I tried to convert to Int, but that one seems to use float, so it overflows in strange ways
        ' If we divide by 10K then it seems we can keep the precision up to 3 decimals and work with smaller numbers
        factor = 10000.0#
        fvalHi = Int(fval / factor)
        fvalLo = fval - factor * fvalHi
        ' I have no idea why but sometimes fvalLo as computed above can be negative !
        ' This must be because the Int(... / ...) rounds up ?
        while fvalLo < 0
           fvalHi = fvalHi - 1
           fvalLo = fvalLo + factor
        end while
        fvalLoInt = Int(fvalLo)
        fvalLoFrac = Int(1000 * (fvalLo - fvalLoInt))
        ' Now fval = factor * fvalHi + fvalLoInt + fvalLoFrac / 1000
        ' print "fvalHi=" + stri(fvalHi) + " fvalLo="+str(fvalLo)+" fvalLoInt="+stri(fvalLoInt)+" fvalLoFrac="+stri(fvalLoFrac)
        ' stri will add a blank prefix for the sign
        if fvalHi > 0 then
           fvalHiStr = self.cwsJsonEncodeInt(fvalHi)
        else
           fvalHiStr = ""
        end if
	fvalLoIntStr = self.cwsJsonEncodeInt(fvalLoInt)
	if fvalHi > 0 then
           fvalLoIntStr = String(4 - Len(fvalLoIntStr), "0") + fvalLoIntStr
        end if
        ' print "fvalHiStr="+fvalHiStr+" fvalLoIntStr="+fvalLoIntStr
        fvalLoFracStr = self.cwsJsonEncodeInt(fvalLoFrac)
        if fvalLoFrac > 0 then
           fvalLoFracStr = String(3 - Len(fvalLoFracStr), "0") + fvalLoFracStr
        end if
        result = sign + fvalHiStr + fvalLoIntStr + "." + fvalLoFracStr
        ' print "Result="+result
        return result
    end function

    ' Encode an integer stripping the leading space
    self.cwsJsonEncodeInt = function (ival) as string
        ivalStr = stri(ival)
        if ival >= 0 then
           return Right(ivalStr, Len(ivalStr) - 1)
        else
           return ivalStr
        end if
    end function

    self.cwsJsonEncodeArray = function (array) as string
        self = m
        ret = box("[")
        notfirst = false
        comma = ""

        for each val in array
            typestr = type(val)
            if typestr="roInvalid" then
                valstr = "null"
            else if typestr="roBoolean" then
                if val then
                    valstr = "true"
                else
                    valstr = "false"
                end if
            else if typestr="roString" or typestr="String" then
                valstr = self.cwsJsonEncodeString(val)
            else if typestr="roInteger" then
                valstr = stri(val)
            else if typestr="roFloat" then
                valstr = str(val)
            else if typestr="roArray" then
                valstr = self.cwsJsonEncodeArray(val)
            else
                valstr = self.cwsJsonEncodeDict(val)
            end if
            if notfirst then
                comma = ", "
            else
                notfirst = true
            end if
            ret.appendstring(comma,len(comma))
            ret.appendstring(valstr,len(valstr))
        end for
        return ret + "]"
    end function

    self.cwsJsonEncodeString = function (line) as string
        regexes = m.regexes
        q = chr(34) 'quote
        b = chr(92) 'backslash
        b2 = b+b
        ret = regexes.bslash.ReplaceAll(line, String(4,b))
        ret = regexes.quote.ReplaceAll(ret, b2+q)
        ret = regexes.bspace.ReplaceAll(ret, b2+"b")
        ret = regexes.tab.ReplaceAll(ret, b2+"t")
        ret = regexes.nline.ReplaceAll(ret, b2+"n")
        ret = regexes.ffeed.ReplaceAll(ret, b2+"f")
        ret = regexes.cret.ReplaceAll(ret, b2+"r")
        ret = regexes.fslash.ReplaceAll(ret, b2+"/")
        return q + ret + q
    end function


    '=================================================================
    ' Parse JSON string into a Brightscript object.
    '
    ' This parser makes some simplifying assumptions about the input:
    '
    ' * The dictionaries have keys that *contain only* alphanumeric
    '   characters plus the underscore.  No spaces, apostrophes,
    '   backslashes, hash marks, dollars, percent, and other funny stuff.
    '   If the key contains anything beyond alphanum and underscore,
    '   the parser returns invalid.
    '
    ' * The string values *do not contain* special JSON chars that
    '   need to be escaped (slashes, quotes, apostrophes, backspaces, etc).
    '   If they do, we will include them in the output, meaning the \n will
    '   show as literal \n, and not the new line.
    '   In particular, \" will be literal backslash followed by the quote,
    '   so the string will end there, and the rest will be invalid and we
    '   return invalid.'
    '
    ' * The input *must* be valid JSON. Otherwise we will return invalid.
    '=================================================================
    self.cwsJsonParser = function (jsonString as string) as dynamic
        self = m
        value_and_rest = self.cwsGetValue(jsonString)
        if value_and_rest = invalid then
            return invalid
        end if
        return value_and_rest.value
    end function

    '----------------------------------------------------------
    ' Return key, value and rest of string packed into the dict.
    ' If matlching the key or the value did not work, return invalid.
    '----------------------------------------------------------
    self.cwsGetKeyValue = function (rest as string) as dynamic
        self = m
        regexes = self.regexes
        result = {}

        if not regexes.cwsKey.IsMatch(rest) then
            return invalid
        end if

        result.key = regexes.cwsKey.Match(rest)[1]
        rest = regexes.cwsKey.Replace(rest, "")

        value_and_rest = self.cwsGetValue(rest)
        if value_and_rest = invalid then
            return invalid
        end if
        result.value = value_and_rest.value
        result.rest = value_and_rest.rest

        return result
    end function

    '----------------------------------------------------------
    ' Return the value and rest of string packed into the dict.
    ' If we could not match the value, return invalid.
    '----------------------------------------------------------
    self.cwsGetValue = function (rest as string) as dynamic
        self = m
        regexes = self.regexes
        result = {}

        'The next token determines the value type
        if regexes.cwsString.IsMatch(rest) then            'string
            result.value = regexes.cwsString.Match(rest)[1]
            result.rest = regexes.cwsString.Replace(rest, "")
        else if regexes.cwsNumber.IsMatch(rest) then      'number
            result.value = val(regexes.cwsNumber.Match(rest)[1])
            result.rest = regexes.cwsNumber.Replace(rest, "")
        else if regexes.cwsOpenBracket.IsMatch(rest) then 'list
            value = []
            rest = regexes.cwsOpenBracket.Replace(rest, "")
            while true
                if regexes.cwsCloseBracket.IsMatch(rest) then
                    rest = regexes.cwsCloseBracket.Replace(rest, "")
                    exit while
                end if
                value_and_rest = self.cwsGetValue(rest)
                if value_and_rest = invalid then
                    return invalid
                end if
                value.Push(value_and_rest.value)
                rest = value_and_rest.rest
            end while
            result.value = value
            result.rest = rest
        else if regexes.cwsOpenBrace.IsMatch(rest) then    'dict
            value = {}
            rest = regexes.cwsOpenBrace.Replace(rest, "")
            while true
                if regexes.cwsCloseBrace.IsMatch(rest) then
                    rest = regexes.cwsCloseBrace.Replace(rest, "")
                    exit while
                end if
                key_value_and_rest = self.cwsGetKeyValue(rest)
                if key_value_and_rest = invalid then
                    return invalid
                end if
                value.AddReplace(key_value_and_rest.key, key_value_and_rest.value)
                rest = key_value_and_rest.rest
            end while
            result.rest = rest
            result.value = value
        else if regexes.cwsTrue.IsMatch(rest) then      'true
            result.value = true
            result.rest = regexes.cwsTrue.Replace(rest, "")
        else if regexes.cwsFalse.IsMatch(rest) then     'false
            result.value = false
            result.rest = regexes.cwsFalse.Replace(rest, "")
        else if regexes.cwsNull.IsMatch(rest) then      'null
            result.value = invalid
            result.rest = regexes.cwsNull.Replace(rest, "")
        else
            return invalid
        end if

        return result
    end function

    self.start ()
    return self
End Function

'--------------
' Configuration
'--------------
function cwsConvivaSettings() as object
    cfg = {}
    ' The next line is changed by set_versions
    cfg.version = "3.0.15"

    cfg.enableLogging = false                      ' change to false to disable debugging output
    cfg.defaultHeartbeatInvervalMs = 20000         ' 20 sec HB interval
    cfg.heartbeatIntervalMs = cfg.defaultHeartbeatInvervalMs
    cfg.maxUtos = 5  ' How large is the pool of UTO objects we re-use for POSTs

    cfg.maxEventsPerHeartbeat = 10
    cfg.apiKey = ""

    cfg.defaultGatewayUrl = "https://cws.conviva.com"

    cfg.gatewayUrl        = cfg.defaultGatewayUrl
    cfg.gatewayPath     = "/0/wsg" 'Gateway URL
    cfg.protocolVersion = "2.5"

    cfg.printHb = false

    cfg.caps = 0
    cfg.maxhbinfos = 2
    cfg.csi_en = false 'By default, disable sending CDN server IP in HB'

    return cfg
end function
' ConvivaAIMonitor Version: 3.0.15
' authors: Kedar Marsada <kmarsada@conviva.com>, Mayank Rastogi <mrastogi@conviva.com>
'
' Common script that is used by Conviva tasks to perform ad insights integrations.
' Used specifically for ad insights integrations done by ConvivaClient APIs.
' Will not be used by LivePass APIs.
' Provides a common interface to integrate with any ad manager.

' This is bundled into core lib for usage with custom conviva tasks for customers using LivePass API for EI & ConvivaClient APIs for AI.
sub handleAdEvent(adData)
    m.ConvivaLpObj = ConvivaLivePassInstance()
    if adData <> invalid
        if adData.type = "ConvivaPodStart" then
            if adData.technology = "Client Side"
                m.ConvivaLpObj.detachStreamer()
                m.ConvivaLpObj.adStart()
            end if
            sendPodStart(adData)
        else if adData.type = "ConvivaPodEnd" then
            sendPodEnd(adData)
            if adData.technology = "Client Side"
                m.ConvivaLpObj.adEnd()
                m.ConvivaLpObj.attachStreamer()
            end if
        else if adData.type = "ConvivaAdLoaded" then
        'Create ad session by extracting metadata from ConvivaAdStart event data'
            if m.adSession = invalid
                adTags = { }
                adTags.SetModeCaseSensitive()
                assetName = "No ad title"
                if adData.assetName <> invalid and Len(adData.assetName.trim()) <> 0
                    assetName = adData.assetName
                end if
                if adData.adid <> invalid
                    adTags["c3.ad.id"] = adData.adid
                end if
                if adData.adsystem <> invalid
                    adTags["c3.ad.system"] = adData.adsystem
                end if
                if adData.mediaFileApiFramework <> invalid
                    adTags["c3.ad.mediaFileApiFramework"] = adData.mediaFileApiFramework
                end if
                if adData.technology <> invalid
                    adTags["c3.ad.technology"] = adData.technology
                end if
                if adData.technology <> "Client Side"
                    adTags["c3.ad.adStitcher"] = adData.adStitcher
                    if adData.isSlate <> invalid
                        adTags["c3.ad.isSlate"] = adData.isSlate
                    else
                        adTags["c3.ad.isSlate"] = "false"
                    end if
                end if
                ' CSR-4960 fix for sequence
                if adData.sequence <> invalid
                    adTags["c3.ad.sequence"] = adData.sequence.trim()
                end if
                if adData.position <> invalid
                    adTags["c3.ad.position"] = adData.position
                end if
                if adData.creativeid <> invalid
                    adTags["c3.ad.creativeId"] = adData.creativeid
                end if
                if adData.adManagerName <> invalid
                    adTags["c3.ad.adManagerName"] = adData.adManagerName
                end if
                if adData.adManagerVersion <> invalid
                    adTags["c3.ad.adManagerVersion"] = adData.adManagerVersion
                end if
                adTags["c3.ad.sessionStartEvent"] = "Loaded"
                if adData.advertiser <> invalid
                    adTags["c3.ad.advertiser"] = adData.advertiser
                end if
                if adData.firstAdSystem <> invalid
                    adTags["c3.ad.firstAdSystem"] = adData.firstAdSystem
                end if
                if adData.firstCreativeId <> invalid
                    adTags["c3.ad.firstCreativeId"] = adData.firstCreativeId
                end if
                if adData.firstAdId <> invalid
                    adTags["c3.ad.firstAdId"] = adData.firstAdId
                end if

                adInfo = ConvivaContentInfo(assetName, adTags)
                if adData.streamUrl <> Invalid or adData.streamUrl = ""
                    adInfo.streamUrl = adData.streamUrl
                else if m.contentStreamUrl <> invalid
                    adInfo.streamUrl = m.contentStreamUrl
                end if

                if adData.isLive <> Invalid
                    adInfo.isLive = adData.isLive
                else if m.top.metadata <> invalid
                    adInfo.isLive = m.top.metadata.isLive
                end if
                    adInfo.contentLength = adData.contentLength
                if adData.streamFormat <> invalid
                    adInfo.streamFormat = adData.streamFormat
                end if
                if (m.top.myvideo = invalid  or (m.top.myvideo <> invalid and (m.top.myvideo.notificationInterval = invalid or m.top.myvideo.notificationInterval > 1))) then
                    m.notificationInterval = 0.5 ' 0.5 is the new standard from Roku for notification interval
                else
                    m.notificationInterval = m.top.myvideo.notificationInterval
                end if
                options = {}
                if adData.moduleName <> invalid
                  options.moduleName = adData.moduleName
                end if
                m.adSession = m.ConvivaLpObj.createAdSession(m.ConvivaLpObj.session, true, adInfo, m.notificationInterval, m.top.myvideo, options)
                m.ConvivaLpObj.setPlayerState(m.adSession, m.ConvivaLpObj.PLAYER_STATES.BUFFERING)
            end if
        else if adData.type = "ConvivaAdStart" then
            'Create ad session by extracting metadata from ConvivaAdStart event data'
            adTags = { }
            adTags.SetModeCaseSensitive()
            assetName = "No ad title"
            if adData.assetName <> invalid and Len(adData.assetName.trim()) <> 0
                assetName = adData.assetName
            end if
            if adData.adid <> invalid
                adTags["c3.ad.id"] = adData.adid
            end if
            if adData.adsystem <> invalid
                adTags["c3.ad.system"] = adData.adsystem
            end if
            if adData.mediaFileApiFramework <> invalid
                adTags["c3.ad.mediaFileApiFramework"] = adData.mediaFileApiFramework
            end if
            if adData.technology <> invalid
                adTags["c3.ad.technology"] = adData.technology
            end if
            if adData.technology <> "Client Side"
                adTags["c3.ad.adStitcher"] = adData.adStitcher
                if adData.isSlate <> invalid
                    adTags["c3.ad.isSlate"] = adData.isSlate
                else
                    adTags["c3.ad.isSlate"] = "false"
                end if
            end if

            ' CSR-4960 fix for sequence
            if adData.sequence <> invalid
                adTags["c3.ad.sequence"] = adData.sequence.trim()
            end if

            if adData.position <> invalid
                adTags["c3.ad.position"] = adData.position
            end if
            if adData.creativeid <> invalid
                adTags["c3.ad.creativeId"] = adData.creativeid
            end if
            if adData.adManagerName <> invalid
                adTags["c3.ad.adManagerName"] = adData.adManagerName
            end if
            if adData.adManagerVersion <> invalid
                adTags["c3.ad.adManagerVersion"] = adData.adManagerVersion
            end if
            if adData.advertiser <> invalid
                adTags["c3.ad.advertiser"] = adData.advertiser
            end if
            if adData.sessionStartEvent <> invalid and m.adSession = invalid
                adTags["c3.ad.sessionStartEvent"] = adData.sessionStartEvent
            else if m.adSession = invalid
                adTags["c3.ad.sessionStartEvent"] = "Start"
            end if
            if adData.firstAdSystem <> invalid
                adTags["c3.ad.firstAdSystem"] = adData.firstAdSystem
            end if
            if adData.firstCreativeId <> invalid
                adTags["c3.ad.firstCreativeId"] = adData.firstCreativeId
            end if
            if adData.firstAdId <> invalid
                adTags["c3.ad.firstAdId"] = adData.firstAdId
            end if

            adInfo = ConvivaContentInfo(assetName, adTags)
            if adData.streamUrl <> Invalid or adData.streamUrl = ""
                adInfo.streamUrl = adData.streamUrl
            else if m.contentStreamUrl <> invalid
                adInfo.streamUrl = m.contentStreamUrl
            end if
            if adData.isLive <> Invalid
                adInfo.isLive = adData.isLive
            else if m.top.metadata <> invalid
                adInfo.isLive = m.top.metadata.isLive
            end if

            adInfo.contentLength = adData.contentLength
            if m.adSession = invalid
                if (m.top.myvideo = invalid  or (m.top.myvideo <> invalid and (m.top.myvideo.notificationInterval = invalid or m.top.myvideo.notificationInterval > 1))) then
                    m.notificationInterval = 0.5 ' 0.5 is the new standard from Roku for notification interval
                else
                    m.notificationInterval = m.top.myvideo.notificationInterval
                end if
                options = {}
                if adData.moduleName <> invalid
                  options.moduleName = adData.moduleName
                end if

                m.adSession = m.ConvivaLpObj.createAdSession(m.ConvivaLpObj.session, true, adInfo, m.notificationInterval, m.top.myvideo, options)
                m.ConvivaLpObj.setPlayerState(m.adSession, m.ConvivaLpObj.PLAYER_STATES.PLAYING)
            else
                m.ConvivaLpObj.updateContentMetadata(m.adSession, adInfo)
            end if
        else if adData.type = "ConvivaAdComplete" then
            if m.adSession <> invalid
                m.ConvivaLpObj.cleanupSession(m.adSession)
                m.adSession = invalid
            end if
        else if adData.type = "ConvivaAdSkip" then
            if m.adSession <> invalid
                m.ConvivaLpObj.cleanupSession(m.adSession)
                m.adSession = invalid
            end if
        else if adData.type = "ConvivaAdError" and adData.errCode <> invalid then
            if m.adSession <> invalid
                m.ConvivaLpObj.reportError(m.adSession, "Error code:"+adData.errcode+" Error Message: "+adData.errmsg, true)
                m.ConvivaLpObj.cleanupSession(m.adSession)
                m.adSession = invalid
            end if
        ' Pause / Resume / Buffering Start & Buffering End are handled in ConvivaAdPlayerState
        else if adData.type = "ConvivaAdPlayerState"
            if m.adSession <> invalid
                m.ConvivaLpObj.setPlayerState(m.adSession, adData.playerState)
            end if
        else if adData.type = "ConvivaAdBitrate"
            if m.adSession <> invalid
                m.adSession.externalBitrateReporting = true
                m.ConvivaLpObj.setBitrateKbps(m.adSession, adData.bitrate)
            end if
        else if adData.type = "ConvivaAdEvent"
            if m.adSession <> invalid
                m.LivePass.sendSessionEvent(m.adSession, adData.eventType, adData.eventDetail)
            end if
        end if
    end if
end sub

sub sendPodStart(podInfo as object)
  m.podStartSent = true
  m.podData = {}
  m.podData.SetModeCaseSensitive()
  m.podData["podPosition"] = podInfo.podPosition
  if(m.podIndex = invalid)
    m.podIndex = 1
  end if
  m.podData["podIndex"] = stri(m.podIndex).trim()
  if podInfo.podDuration <> invalid
    m.podData["podDuration"] = stri(podInfo.podDuration).trim()
  end if
  m.ConvivaLpObj.sendSessionEvent(m.ConvivaLpObj.session, "Conviva.PodStart", m.podData)
end sub

sub sendPodEnd(podInfo as object)
  if m.podStartSent = true then
    m.podStartSent = false

    if m.podData.DoesExist("podDuration")
      m.podData.Delete("podDuration")
    end if

    if podInfo.podPosition <> invalid
      m.podData["podPosition"] = podInfo.podPosition
    end if
    m.podData["podIndex"] = stri(m.podIndex).trim()
    m.ConvivaLpObj.sendSessionEvent(m.ConvivaLpObj.session, "Conviva.PodEnd", m.podData)
    m.podIndex = m.podIndex + 1
  end if
end sub
