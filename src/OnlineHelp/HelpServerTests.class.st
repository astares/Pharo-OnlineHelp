Class {
	#name : #HelpServerTests,
	#superclass : #TestCase,
	#category : #'OnlineHelp-Tests'
}

{ #category : #utilities }
HelpServerTests >> dispatcherAvailableFor: contextRoot [

	|delegate|	
	delegate := HelpServer server delegate.
	self assert: (delegate dispatchMap includesKey: contextRoot)
]

{ #category : #testing }
HelpServerTests >> testDefaultPort [

	self assert: HelpServer defaultPort = 8080
]

{ #category : #testing }
HelpServerTests >> testDelegate [

	|delegate|	
	delegate := HelpServer server delegate.
	
	self assert: (delegate dispatchMap includesKey: '/')
]

{ #category : #testing }
HelpServerTests >> testFavIconContext [

	self dispatcherAvailableFor: 'favicon.ico'
]

{ #category : #testing }
HelpServerTests >> testFilesContext [

	self dispatcherAvailableFor: 'files'
]

{ #category : #testing }
HelpServerTests >> testPortAvailable [

	self assert: HelpServer port isInteger 
	

]

{ #category : #testing }
HelpServerTests >> testRootContext [

	self dispatcherAvailableFor: '/'
]

{ #category : #testing }
HelpServerTests >> testRunning [

	|alreadyRunning response |
	alreadyRunning := HelpServer isRunning.
	
	HelpServer start.
	
	#('/' '/api' '/tutorials' '/welcome') do: [:context |  
		response := ZnEasy get: 'http://localhost:', HelpServer port asString, context.
		self assert: response statusLine code = 200.
	].
	alreadyRunning ifFalse: [ HelpServer stop ]
]

{ #category : #testing }
HelpServerTests >> testServerAccessibility [

	|server|	
	server := HelpServer server.
	self 
		assert: server notNil;
		assert: server port = HelpServer port;
		assert: server isRunning = HelpServer isRunning 
		
	
	
]
