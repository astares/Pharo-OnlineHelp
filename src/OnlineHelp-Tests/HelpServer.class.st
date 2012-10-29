Class {
	#name : #HelpServer,
	#superclass : #Object,
	#instVars : [
		'prefixMap'
	],
	#classVars : [
		'OnlineHelpPort'
	],
	#category : #'OnlineHelp-Core'
}

{ #category : #private }
HelpServer class >> dispatcherClass [
	"Returns the default dispatcher class."
	
	^HelpRequestDispatcher 
]

{ #category : #testing }
HelpServer class >> isRunning [
	"Return true if the server is running"
	 
	^self server isRunning
]

{ #category : #settings }
HelpServer class >> onlineHelpPort [
	"Return the port to use for the online help, an Integer"
	
	^OnlineHelpPort ifNil: [ OnlineHelpPort := 8080 ]
]

{ #category : #settings }
HelpServer class >> onlineHelpPort: aPort [
	"Sets the port to use for the online help. If the server is already running on
	  a different port then it is restarted."
	
	|requiresRestart|
	requiresRestart := OnlineHelpPort = aPort and: [ self isRunning ].
	requiresRestart ifTrue: [self stop].
	OnlineHelpPort := aPort.
	requiresRestart ifTrue: [self start].
	
]

{ #category : #settings }
HelpServer class >> onlineHelpSettingsOn: aBuilder [ 
	"Build the possible settings"	
	<systemsettings>
	
	(aBuilder group: #help) 
		label: 'Online Help' translated;
		description: 'All online help related settings' translated;
		noOrdering;
		with: [ 			 
			(aBuilder setting: #onlineHelpPort)
					label: 'HTTP Port' translated;
					description: 'The HTTP port for the online help' translated.
	]
]

{ #category : #accessing }
HelpServer class >> server [
	"Return the server instance"
	
	^(ZnServer defaultOn: 8080) 
]

{ #category : #running }
HelpServer class >> start [
	"Start the online help server.
	
		HelpServer start
	"
	self isRunning ifTrue: [^self server].
	^self server
		delegate: self dispatcherClass new;
		start
       
]

{ #category : #running }
HelpServer class >> stop [
	"Stop the online help server.
	
		HelpServer stop
	"
	
	self isRunning ifFalse: [^self server].	
	^self server
		stop
       
]
