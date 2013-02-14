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
HelpServerTests >> testServerAccessibility [

	|server|	
	server := HelpServer server.
	self 
		assert: server notNil;
		assert: server port = HelpServer port;
		assert: server isRunning = HelpServer isRunning 
		
	
	
]
