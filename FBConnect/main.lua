-- 
-- Project: Facebook Connect sample app
--
-- Date: July 7, 2015
--
-- Version: 1.7
--
-- File name: main.lua
--
-- Author: Corona Labs
--
-- Abstract: Presents the Facebook Connect login dialog, and then posts to the user's stream
-- (Also demonstrates the use of external libraries.)
--
-- Demonstrates: webPopup, network, Facebook library
--
-- File dependencies: facebook.lua
--
-- Target devices: Simulator and Device
--
-- Limitations: Requires internet access; no error checking if connection fails
--
-- Update History:
--	v1.1		Layout adapted for Android/iPad/iPhone4
--  v1.2		Modified for new Facebook Connect API (from build #243)
--  v1.3		Added buttons to: Post Message, Post Photo, Show Dialog, Logout
--  v1.4		Added  ...{"publish_stream"} .. permissions setting to facebook.login() calls.
--	v1.5		Added single sign-on support in build.settings (must replace XXXXXXXXX with valid facebook appId)
--	v1.6		Modified the build.settings file to get the plugin for iOS.
--  v1.7		Added more buttons to test features. Upgraded sample to use Facebook v4 plugin.

--
-- Comments:
-- Requires API key and application secret key from Facebook. To begin, log into your Facebook
-- account and add the "Developer" application, from which you can create additional apps.
--
-- IMPORTANT: Please ensure your app is compatible with Facebook Single Sign-On or your
--			  Facebook implementation will fail! See the following blog post for more details:
--			  http://www.coronalabs.com/links/facebook-sso
--
-- Sample code is MIT licensed, see http://www.coronalabs.com/links/code/license
-- Copyright (C) 2010 Corona Labs Inc. All Rights Reserved.
--
-- Supports Graphics 2.0
---------------------------------------------------------------------------------------

local centerX = display.contentCenterX
local centerY = display.contentCenterY
local _W = display.contentWidth
local _H = display.contentHeight

-- Comment out the next line when through debugging your app.
io.output():setvbuf('no') 		-- **debug: disable output buffering for Xcode Console **tjn

local widget = require("widget")
local facebook = require("plugin.facebook.v4")
local json = require("json")

display.setStatusBar( display.HiddenStatusBar )
	
-- Facebook Commands
local fbCommand	= nil	-- forward reference
local LOGOUT = 1
local PUBLISH_INSTALL = 2
local POST_PHOTO = 3
local GET_USER_INFO = 4
local GET_TAGGABLE_FRIENDS = 5
local SHOW_FEED_W_PHOTO_DIALOG = 6
local SHOW_REQUEST_DIALOG = 7

-- Layout Locations
local ButtonOrigX = 160
local ButtonOrigY = 152.5
local ButtonYOffset = 35
local StatusMessageY = 420		-- position of status message

-- Saved request info
local loggedInUserID = nil;
local taggableFriends = nil;

local background = display.newImage( "facebook_bkg.png", centerX, centerY, true ) -- flag overrides large image downscaling

-- This function is useful for debugging problems with using FB Connect's web api,
-- e.g. you passed bad parameters to the web api and get a response table back
local function printTable( t, label, level )
	if label then print( label ) end
	level = level or 1

	if t then
		for k,v in pairs( t ) do
			local prefix = ""
			for i=1,level do
				prefix = prefix .. "\t"
			end

			print( prefix .. "[" .. tostring(k) .. "] = " .. tostring(v) )
			if type( v ) == "table" then
				print( prefix .. "{" )
				printTable( v, nil, level + 1 )
				print( prefix .. "}" )
			end
		end
	end
end

local function createStatusMessage( message, x, y )
	-- Show text, using default bold font of device (Helvetica on iPhone)
	local textObject = display.newText( message, 0, 0, native.systemFontBold, 24 )
	textObject:setFillColor( 1,1,1 )

	-- A trick to get text to be centered
	local group = display.newGroup()
	group.x = x
	group.y = y
	group:insert( textObject, true )

	-- Insert rounded rect behind textObject
	local r = 10
	local roundedRect = display.newRoundedRect( 0, 0, textObject.contentWidth + 2*r, textObject.contentHeight + 2*r, r )
	roundedRect:setFillColor( 55/255, 55/255, 55/255, 190/255 )
	group:insert( 1, roundedRect, true )

	group.textObject = textObject
	return group
end

local statusMessage = createStatusMessage( "   Not connected  ", centerX, StatusMessageY )

-- New Facebook Connection listener
--
local function listener( event )

--- Debug Event parameters printout --------------------------------------------------
--- Prints Events received up to 20 characters. Prints "..." and total count if longer
---
	print( "Facebook Listener events:" )
	
	local maxStr = 20		-- set maximum string length
	local endStr
	
	for k,v in pairs( event ) do
		local valueString = tostring(v)
		if string.len(valueString) > maxStr then
			endStr = " ... #" .. tostring(string.len(valueString)) .. ")"
		else
			endStr = ")"
		end
		print( "   " .. tostring( k ) .. "(" .. tostring( string.sub(valueString, 1, maxStr ) ) .. endStr )
	end
--- End of debug Event routine -------------------------------------------------------

    print( "event.name", event.name ) -- "fbconnect"
    print( "event.type:", event.type ) -- type is either "session" or "request" or "dialog"
	print( "isError: " .. tostring( event.isError ) )
	print( "didComplete: " .. tostring( event.didComplete) )
-----------------------------------------------------------------------------------------
	-- After a successful login event, send the FB command
	-- Note: If the app is already logged in, we will still get a "login" phase
	--
    if ( "session" == event.type ) then
        -- event.phase is one of: "login", "loginFailed", "loginCancelled", "logout"
		statusMessage.textObject.text = event.phase		-- tjn Added
		
		print( "Session Status: " .. event.phase )
		
		if event.phase ~= "login" then
			-- Exit if login error
			return
		end

		if fbCommand then
			print( "Facebook Command: " .. fbCommand )
		else
			print( "No command to execute" )
		end

		-- The following displays a Facebook dialog box for posting to your Facebook Wall
		if fbCommand == GET_TAGGABLE_FRIENDS then
			-- Need to get the Facebook ID of whoever's logged in with the "Get User Info" button.
			local response = facebook.request( loggedInUserID .. "/taggable_friends" )
			printTable(response)
		end

		-- This displays a Facebook Dialog for posting a link with a photo to your Facebook Wall
		if fbCommand == SHOW_FEED_W_PHOTO_DIALOG then

			-- Tag the first two friends we gathered if applicable
			-- You need to use the "link" action for the peopleIDs to actually be used!
			-- "feed" is the standard "post status message" dialog
			local response = facebook.showDialog( "link", {
				name = "Composer GUI",
				link = "http://www.coronalabs.com/links/forum",
				description = "Corona SDK for developing iOS and Android apps with the same code base.",
				picture = "https://coronalabs.com/wp-content/uploads/2014/06/ComposerGUI_inside_Panel1010x6002.jpg",
				peopleIds = {taggableFriends[1].id, taggableFriends[2].id},
			})
			printTable(response)
		end

		-- This displays a Facebook Dialog for sending game requests to other users
		if fbCommand == SHOW_REQUEST_DIALOG then
			-- "feed" is the standard "post status message" dialog
			local response = facebook.showDialog( "apprequests", {
				message = "Come check out Facebook's integration into Corona SDK",
				title = "Send a game request to others"
			})
			printTable(response)
		end

		-- Request the current logged in user's info and save it
		if fbCommand == GET_USER_INFO then
			local response = facebook.request( "me" )
			printTable(response)
--			facebook.request( "me/friends" )		-- Alternate request
		end

		-- This code posts a photo image to your Facebook Wall
		-- It includes a message as well
		if fbCommand == POST_PHOTO then
			local time = os.date("*t")
			local attachment = {
				name = "Developing a Facebook Connect app using the Corona SDK!",
				link = "http://www.coronalabs.com/links/forum",
				caption = "Link caption",
				description = "Corona SDK for developing iOS and Android apps with the same code base.",
				picture = "http://www.coronalabs.com/links/demo/Corona90x90.png",
				actions = json.encode( { { name = "Learn More", link = "http://coronalabs.com" } } ),
				message = "Posting from Corona SDK! " ..
					os.date("%A, %B %e")  .. ", " .. time.hour .. ":"
					.. time.min .. "." .. time.sec
			}
		
			local response = facebook.request( "me/feed", "POST", attachment )		-- posting the photo
			printTable(response)
		end
		
-----------------------------------------------------------------------------------------

    elseif ( "request" == event.type ) then
        -- event.response is a JSON object from the FB server
        local response = event.response
        
		if ( not event.isError ) then
	        response = json.decode( event.response )
	        
	        if fbCommand == GET_USER_INFO then
				statusMessage.textObject.text = response.name
				printTable( response, "User Info", 3 )
				print( "name", response.name )
				loggedInUserID = response.id
				
			elseif fbCommand == GET_TAGGABLE_FRIENDS then
				printTable( response, "friends", 3 )
				statusMessage.textObject.text = "Got taggable friends!"
				taggableFriends = response.data

			elseif fbCommand == POST_PHOTO then
				printTable( response, "photo", 3 )
				statusMessage.textObject.text = "Photo Posted"

			else
				-- Unknown command response
				print( "Unknown command response" )
				statusMessage.textObject.text = "Unknown ?"
			end

        else
        	-- Post Failed
			statusMessage.textObject.text = "Post failed"
			printTable( event.response, "Post Failed Response", 3 )
		end
		
	elseif ( "dialog" == event.type ) then
		-- showDialog response
		--
		print( "dialog response:", event.response )
		statusMessage.textObject.text = event.response
    end
end

---------------------------------------------------------------------------------------------------
-- NOTE: To create a mobile app that interacts with Facebook Connect, first log into Facebook
-- and create a new Facebook application. That will give you the "API key" and "application secret" 
-- that should be used in the following lines:

local appId = 1435768153407403 	-- Add  your App ID here (also go into build.settings and replace XXXXXXXXX with your appId under CFBundleURLSchemes)
local apiKey = nil	-- Not needed at this time
---------------------------------------------------------------------------------------------------


-- NOTE: You must provide a valid application id provided from Facebook

facebook.login( appId, listener )

-- ***
-- ************************ Buttons Functions ********************************
-- ***
local function logOut_onRelease( event )
	-- call the login method of the FB session object, passing in a handler
	-- to be called upon successful login.
	fbCommand = LOGOUT
	facebook.logout()
end

local function publishInstall_onRelease( event )
	fbCommand = PUBLISH_INSTALL
	facebook.publishInstall()
end

local function postPhoto_onRelease( event )
	-- call the login method of the FB session object, passing in a handler
	-- to be called upon successful login.
	fbCommand = POST_PHOTO
	facebook.login( appId, listener,  {"publish_actions"}  )
end

local function getInfo_onRelease( event )
	-- call the login method of the FB session object, passing in a handler
	-- to be called upon successful login.
	fbCommand = GET_USER_INFO
	facebook.login( appId, listener, {"publish_actions"}  )
end

local function getTaggableFriends_onRelease( event )
	-- call the login method of the FB session object, passing in a handler
	-- to be called upon successful login.
	fbCommand = GET_TAGGABLE_FRIENDS
	facebook.login( appId, listener, {"publish_actions"}  )
end

local function showFeedWPhotoDialog_onRelease( event )
	-- call the login method of the FB session object, passing in a handler
	-- to be called upon successful login.
	fbCommand = SHOW_FEED_W_PHOTO_DIALOG
	facebook.login( appId, listener, {"publish_actions"}  )
end

local function showRequestDialog_onRelease( event )
	-- call the login method of the FB session object, passing in a handler
	-- to be called upon successful login.
	fbCommand = SHOW_REQUEST_DIALOG
	facebook.login( appId, listener, {"publish_actions"}  )
end

-- ***
-- ************************ Create Buttons ********************************
-- ***

-- "Logout with Facebook" button
local logoutButton = widget.newButton
{
	defaultFile = "fbButton184.png",
	overFile = "fbButtonOver184.png",
	label = "Logout",
	labelColor = 
	{ 
		default = { 255, 255, 255 }, 
	},
	fontSize = 12,
	onRelease = logOut_onRelease,
}
logoutButton.x = ButtonOrigX
logoutButton.y = 25

-- "Publish Install with Facebook" button
local publishInstallButton = widget.newButton
{
	defaultFile = "fbButton184.png",
	overFile = "fbButtonOver184.png",
	label = "Publish Install",
	labelColor = 
	{ 
		default = { 255, 255, 255 }, 
	},
	fontSize = 12,
	onRelease = publishInstall_onRelease,
}
publishInstallButton.x = ButtonOrigX
publishInstallButton.y = ButtonOrigY

-- "Post Photo with Facebook" button
local postPhotoButton = widget.newButton
{
	defaultFile = "fbButton184.png",
	overFile = "fbButtonOver184.png",
	label = "Post Photo",
	labelColor = 
	{ 
		default = { 255, 255, 255 }, 
	},
	fontSize = 12,
	onRelease = postPhoto_onRelease,
}
postPhotoButton.x = ButtonOrigX
postPhotoButton.y = ButtonOrigY + ButtonYOffset

-- "Get User Info with Facebook" button
local getInfoButton = widget.newButton
{
	defaultFile = "fbButton184.png",
	overFile = "fbButtonOver184.png",
	label = "Get User",
	labelColor = 
	{ 
		default = { 255, 255, 255 }, 
	},
	fontSize = 12,
	onRelease = getInfo_onRelease,
}
getInfoButton.x = ButtonOrigX
getInfoButton.y = ButtonOrigY + ButtonYOffset * 2

-- "Get Taggable Friends" button
local getTaggableFriendsButton = widget.newButton
{
	defaultFile = "fbButton184.png",
	overFile = "fbButtonOver184.png",
	label = "Get Taggable Friends",
	labelColor = 
	{ 
		default = { 255, 255, 255 }, 
	},
	fontSize = 12,
	onRelease = getTaggableFriends_onRelease,
}
getTaggableFriendsButton.x = ButtonOrigX
getTaggableFriendsButton.y = ButtonOrigY + ButtonYOffset * 3

-- "Show Feed with Photo with Facebook" button
local showFeedWPhotoDialogButton = widget.newButton
{
	defaultFile = "fbButton184.png",
	overFile = "fbButtonOver184.png",
	label = "Show Feed W/ Photo",
	labelColor = 
	{ 
		default = { 255, 255, 255 }, 
	},
	fontSize = 12,
	onRelease = showFeedWPhotoDialog_onRelease,
}
showFeedWPhotoDialogButton.x = ButtonOrigX
showFeedWPhotoDialogButton.y = ButtonOrigY + ButtonYOffset * 4

-- "Show Request Dialog with Facebook" button
local showRequestDialogButton = widget.newButton
{
	defaultFile = "fbButton184.png",
	overFile = "fbButtonOver184.png",
	label = "Show Request Dialog",
	labelColor = 
	{ 
		default = { 255, 255, 255 }, 
	},
	fontSize = 12,
	onRelease = showRequestDialog_onRelease,
}
showRequestDialogButton.x = ButtonOrigX
showRequestDialogButton.y = ButtonOrigY + ButtonYOffset * 5