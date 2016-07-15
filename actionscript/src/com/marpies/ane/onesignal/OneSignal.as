/**
 * Copyright 2016 Marcel Piestansky (http://marpies.com)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.marpies.ane.onesignal {

    import flash.events.StatusEvent;
    import flash.external.ExtensionContext;
    import flash.system.Capabilities;
    import flash.utils.Dictionary;

    public class OneSignal {

        private static const TAG:String = "[OneSignal]";
        private static const EXTENSION_ID:String = "com.marpies.ane.onesignal";

        private static var mContext:ExtensionContext;

        /* Event codes */
        private static const TOKEN_RECEIVED:String = "tokenReceived";
        private static const NOTIFICATION_RECEIVED:String = "notificationReceived";
        private static const TAGS_RECEIVED:String = "tagsReceived";

        /* Callbacks */
        private static var mTokenCallbacks:Vector.<Function> = new <Function>[];
        private static var mNotificationCallbacks:Vector.<Function> = new <Function>[];
        private static var mCallbackMap:Dictionary;
        private static var mCallbackIdCounter:int;

        /* Misc */
        private static var mInitialized:Boolean;
        private static var mLogEnabled:Boolean;
        private static const iOS:Boolean = Capabilities.manufacturer.indexOf( "iOS" ) > -1;
        private static const ANDROID:Boolean = Capabilities.manufacturer.indexOf( "Android" ) > -1;

        /**
         * @private
         * Do not use. OneSignal is a static class.
         */
        public function OneSignal() {
            throw Error( "OneSignal is static class." );
        }

        /**
         *
         *
         * Public API
         *
         *
         */

        /**
         * Initializes extension context and native SDKs. Call as early as possible to be able to retrieve notifications
         * which are launching the application.
         * 
         * @param oneSignalAppID ID of the app created in the OneSignal dashboard.
         * @param autoRegister <strong>iOS only</strong> - Set to <code>true</code> to register with notification server
         *                     immediately after initialization. If set to <code>false</code>, <code>OneSignal.register()</code>
         *                     must be called later to successfully register with Apple servers and receive notifications.
         * @param showLogs Set to <code>true</code> to show extension log messages.
         *
         * @see #register()
         * 
         * @return <code>true</code> if the extension context was created, <code>false</code> otherwise
         */
        public static function init( oneSignalAppID:String, autoRegister:Boolean = false, showLogs:Boolean = false ):Boolean {
            if( !isSupported ) return false;
            if( mInitialized ) return true;

            if( iOS && oneSignalAppID === null ) throw new ArgumentError( "Parameter oneSignalAppID cannot be null when targeting iOS." );
            mLogEnabled = showLogs;

            /* Initialize context */
            if( !initExtensionContext() ) {
                log( "Error creating extension context for " + EXTENSION_ID );
                return false;
            }

            mCallbackMap = new Dictionary();
            /* Listen for native library events */
            mContext.addEventListener( StatusEvent.STATUS, onStatus );

            /* Call init */
            mContext.call( "init", oneSignalAppID, autoRegister, showLogs );

            mInitialized = true;
            return true;
        }

        /**
         * <strong>(iOS only)</strong> - Call this method when you want to prompt the user to accept push notifications.
         * Android devices automatically register silently during initialization.
         *
         * <p>Extension must be initialized using <code>OneSignal.init()</code> with <code>autoRegister</code>
         * parameter set to <code>false</code> before calling this method.</p>
         */
        public static function register():void {
            if( !isSupported ) return;
            validateExtensionContext();

            mContext.call( "register" );
        }

        /**
         * You can call this method with <code>false</code> to opt users out of receiving all notifications
         * through OneSignal. You can pass <code>true</code> later to opt users back into notifications.
         * Extension must be initialized using <code>OneSignal.init()</code> before calling this method.
         */
        public static function setSubscription( value:Boolean ):void {
            if( !isSupported ) return;
            validateExtensionContext();

            mContext.call( "setSubscription", value );
        }

        /**
         * Tag a user based on an app event of your choosing so later you can create
         * segments in the OneSignal dashboard to target these users.
         *
         * <p>Consider using <code>OneSignal.sendTags()</code> to send more than one tag at a time.</p>
         *
         * <p>Extension must be initialized using <code>OneSignal.init()</code> before calling this method.</p>
         *
         * @param key Key of your choosing to create or update.
         * @param value Value to set on the key. Empty <code>String</code> removes the key.
         *
         * @see #sendTags()
         * @see #getTags()
         * @see #deleteTag()
         * @see #deleteTags()
         */
        public static function sendTag( key:String, value:String ):void {
            if( !isSupported ) return;
            validateExtensionContext();

            if( key === null ) throw new ArgumentError( "Parameter key cannot be null." );
            if( value === null ) throw new ArgumentError( "Parameter value cannot be null." );

            var tag:Object = {};
            tag[key] = value;
            sendTags( tag );
        }

        /**
         * Tag a user based on an app event of your choosing so later you can create
         * segments in the OneSignal dashboard to target these users.
         *
         * <p>This method allows sending multiple tags at once. Consider using <code>OneSignal.sendTag()</code>
         * to send a single tag.</p>
         *
         * <p>Extension must be initialized using <code>OneSignal.init()</code> before calling this method.</p>
         *
         * @param tags Key-value pairs of your choosing to create or update, for example:
         * <listing version="3.0">
         * OneSignal.sendTags( {
         *    profession: "warrior",
         *    area: "desert"
         * } );
         * </listing>
         *
         * @see #sendTag()
         * @see #getTags()
         * @see #deleteTag()
         * @see #deleteTags()
         */
        public static function sendTags( tags:Object ):void {
            if( !isSupported ) return;
            validateExtensionContext();

            if( tags === null ) throw new ArgumentError( "Parameter tags cannot be null." );

            mContext.call( "sendTags", getVectorFromObject( tags ) );
        }

        /**
         * Retrieves a list of tags that have been set on the user.
         *
         * <p>Extension must be initialized using <code>OneSignal.init()</code> before calling this method.</p>
         *
         * @param callback Function with the following signature:
         * <listing version="3.0">
         * function callback( tags:Object ):void {
         *    // tags may be null if there's a connection error or user has not been tagged
         * };
         * </listing>
         *
         * @see #sendTag()
         * @see #sendTags()
         * @see #deleteTag()
         * @see #deleteTags()
         */
        public static function getTags( callback:Function ):void {
            if( !isSupported ) return;
            if( callback === null ) return;

            validateExtensionContext();

            mContext.call( "getTags", registerCallback( callback ) );
        }

        /**
         * Deletes a tag that was previously set on a user using <code>OneSignal.sendTag()</code> or
         * <code>OneSignal.sendTags()</code>. Consider using <code>OneSignal.deleteTags()</code> if you need
         * to delete more than one tag at a time.
         *
         * <p>Extension must be initialized using <code>OneSignal.init()</code> before calling this method.</p>
         *
         * @param key Key to delete.
         *
         * @see #sendTag()
         * @see #sendTags()
         * @see #getTags()
         * @see #deleteTags()
         */
        public static function deleteTag( key:String ):void {
            if( !isSupported ) return;
            validateExtensionContext();

            if( key === null ) throw new ArgumentError( "Parameter key cannot be null." );
            deleteTags( new <String>[key] );
        }

        /**
         * Deletes tags that were previously set on a user using <code>OneSignal.sendTag()</code> or
         * <code>OneSignal.sendTags()</code>. Consider using <code>OneSignal.deleteTag()</code> to delete
         * a single tag.
         *
         * <p>Extension must be initialized using <code>OneSignal.init()</code> before calling this method.</p>
         *
         * @param keys List of keys to delete.
         *
         * @see #sendTag()
         * @see #sendTags()
         * @see #getTags()
         * @see #deleteTag()
         */
        public static function deleteTags( keys:Vector.<String> ):void {
            if( !isSupported ) return;
            validateExtensionContext();

            if( keys === null ) throw new ArgumentError( "Parameter keys cannot be null." );

            mContext.call( "deleteTags", keys );
        }

        /**
         * Adds callback that will be called when user registers for notifications and push token is received.
         * @param callback Function with the following signature:
         * <listing version="3.0">
         * function callback( oneSignalUserId:String, pushToken:String ):void {
         *    // pushToken may be null if there's an error (server side, connection error...)
         * };
         * </listing>
         *
         * @see #removeTokenReceivedCallback()
         */
        public static function addTokenReceivedCallback( callback:Function ):void {
            if( !isSupported ) return;

            if( callback === null ) throw new ArgumentError( "Parameter callback cannot be null." );

            if( mTokenCallbacks.indexOf( callback ) < 0 ) {
                mTokenCallbacks[mTokenCallbacks.length] = callback;
            }
        }

        /**
         * Removes callback that was added earlier using <code>OneSignal.addTokenReceivedCallback</code>
         * @param callback Function to remove.
         *
         * @see #addTokenReceivedCallback()
         */
        public static function removeTokenReceivedCallback( callback:Function ):void {
            if( !isSupported ) return;

            if( callback === null ) throw new ArgumentError( "Parameter callback cannot be null." );

            var index:int = mTokenCallbacks.indexOf( callback );
            if( index >= 0 ) {
                mTokenCallbacks.removeAt( index );
            }
        }

        /**
         * Adds callback that will be called when user taps a notification
         * or when notification is received while the app is in foreground.
         * @param callback Function with the following signature:
         * <listing version="3.0">
         * function callback( notification:OneSignalNotification ):void {
         *
         * };
         * </listing>
         *
         * @see #removeNotificationReceivedCallback()
         */
        public static function addNotificationReceivedCallback( callback:Function ):void {
            if( !isSupported ) return;

            if( callback === null ) throw new ArgumentError( "Parameter callback cannot be null." );

            if( mNotificationCallbacks.indexOf( callback ) < 0 ) {
                mNotificationCallbacks[mNotificationCallbacks.length] = callback;
            }
        }

        /**
         * Removes callback that was added earlier using <code>OneSignal.addNotificationReceivedCallback</code>
         * @param callback Function to remove.
         *
         * @see #addNotificationReceivedCallback()
         */
        public static function removeNotificationReceivedCallback( callback:Function ):void {
            if( !isSupported ) return;

            if( callback === null ) throw new ArgumentError( "Parameter callback cannot be null." );

            var index:int = mNotificationCallbacks.indexOf( callback );
            if( index >= 0 ) {
                mNotificationCallbacks.removeAt( index );
            }
        }

        /**
         * Disposes native extension context.
         */
        public static function dispose():void {
            if( !isSupported ) return;
            validateExtensionContext();

            mContext.removeEventListener( StatusEvent.STATUS, onStatus );

            mContext.dispose();
            mContext = null;
        }

        /**
         *
         *
         * Getters / Setters
         *
         *
         */

        /**
         * Version of the native OneSignal SDK.
         */
        public static function get sdkVersion():String {
            if( !isSupported ) return null;
            if( !mInitialized && !initExtensionContext() ) {
                return null;
            }

            return mContext.call( "sdkVersion" ) as String;
        }

        /**
         * Extension version.
         */
        public static function get version():String {
            return "0.5.0";
        }

        /**
         * Supported on iOS and Android.
         */
        public static function get isSupported():Boolean {
            return iOS || ANDROID;
        }

        /**
         * Returns <code>true</code> if <code>OneSignal.init()</code> has been executed successfully.
         *
         * @see #init()
         */
        public static function get isInitialized():Boolean {
            return mInitialized;
        }

        /**
         *
         *
         * Private API
         *
         *
         */

        /**
         * Initializes extension context.
         * @return <code>true</code> if initialized successfully, <code>false</code> otherwise.
         */
        private static function initExtensionContext():Boolean {
            if( mContext === null ) {
                mContext = ExtensionContext.createExtensionContext( EXTENSION_ID, null );
            }
            return mContext !== null;
        }

        private static function validateExtensionContext():void {
            if( !mContext ) throw new Error( "OneSignal extension was not initialized. Call init() first." );
        }

        private static function onStatus( event:StatusEvent ):void {
            var responseJSON:Object = null;
            var i:int;
            var length:int;
            switch( event.code ) {
                case TOKEN_RECEIVED:
                    responseJSON = JSON.parse( event.level );
                    length = mTokenCallbacks.length;
                    for( i = 0; i < length; ++i ) {
                        mTokenCallbacks[i]( responseJSON.userId, responseJSON.pushToken );
                    }
                    return;
                case NOTIFICATION_RECEIVED:
                    responseJSON = JSON.parse( event.level );
                    length = mNotificationCallbacks.length;
                    for( i = 0; i < length; ++i ) {
                        mNotificationCallbacks[i]( OneSignalNotification.fromJSON( responseJSON ) );
                    }
                    return;
                case TAGS_RECEIVED:
                    responseJSON = JSON.parse( event.level );
                    var callbackID:int = ("callbackID" in responseJSON) ? responseJSON.callbackID : -1;
                    var callback:Function = getCallback( callbackID );
                    if( callback !== null ) {
                        var tags:Object = responseJSON.tags;
                        if( tags is String ) {
                            tags = JSON.parse( tags as String );
                        }
                        callback( tags );
                    }
                    return;
            }
        }

        /**
         * Registers given callback and generates ID which is used to look the callback up when it is time to call it.
         * @param callback Function to register.
         * @return ID of the callback.
         */
        private static function registerCallback( callback:Function ):int {
            if( callback == null ) return -1;

            mCallbackMap[mCallbackIdCounter] = callback;
            return mCallbackIdCounter++;
        }

        /**
         * Gets registered callback with given ID.
         * @param callbackID ID of the callback to retrieve.
         * @return Callback registered with given ID, or <code>null</code> if no such callback exists.
         */
        private static function getCallback( callbackID:int ):Function {
            if( callbackID == -1 || !(callbackID in mCallbackMap) ) return null;
            return mCallbackMap[callbackID];
        }

        /**
         * Unregisters callback with given ID.
         * @param callbackID ID of the callback to unregister.
         */
        private static function unregisterCallback( callbackID:int ):void {
            if( callbackID in mCallbackMap ) {
                delete mCallbackMap[callbackID];
            }
        }

        /**
         * Returns list of key-values from key-value object, e.g. { "key": "val" } -> [ "key", "val" ].
         * @param object Key-value object to transform into list.
         * @return List of key-values from <code>object</code>, or null if <code>object</code> is null.
         */
        private static function getVectorFromObject( object:Object ):Vector.<String> {
            var properties:Vector.<String> = null;
            if( object ) {
                properties = new <String>[];
                /* Create a list of object properties, that is key followed by its value */
                for( var key:String in object ) {
                    properties[properties.length] = key;
                    properties[properties.length] = object[key];
                }
            }
            return properties;
        }

        private static function log( message:String ):void {
            if( mLogEnabled ) {
                trace( TAG, message );
            }
        }

    }
}
