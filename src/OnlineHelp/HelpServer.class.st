Class {
	#name : #HelpServer,
	#superclass : #Object,
	#classVars : [
		'Port',
		'Server'
	],
	#category : #'OnlineHelp-Core-Server'
}

{ #category : #accessing }
HelpServer class >> defaultPort [
	"Returns the default port "
	
	^8080
]

{ #category : #private }
HelpServer class >> dispatcherClass [
	"Returns the default dispatcher class."
	
	^HelpRequestDispatcher 
]

{ #category : #private }
HelpServer class >> initServer [
	^ZnServer defaultOn: self defaultPort
]

{ #category : #testing }
HelpServer class >> isRunning [
	"Return true if the server is running"
	 
	^self server isRunning
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
			(aBuilder setting: #port)
					label: 'HTTP Port' translated;
					description: 'The HTTP port for the online help' translated.
	]
]

{ #category : #settings }
HelpServer class >> port [
	"Return the port to use for the online help, an Integer"
	
	^Port ifNil: [ Port := self defaultPort ]
]

{ #category : #settings }
HelpServer class >> port: aPort [
	"Sets the port to use for the online help. If the server is already running on
	  a different port then it is restarted."
	
	|requiresRestart|
	requiresRestart := Port = aPort and: [ self isRunning ].
	requiresRestart ifTrue: [self stop].
	Port := aPort.
	requiresRestart ifTrue: [self start].
	
]

{ #category : #accessing }
HelpServer class >> server [
	"Return the server instance"
	
	Server ifNil: [ Server := self initServer ].
	^Server
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
