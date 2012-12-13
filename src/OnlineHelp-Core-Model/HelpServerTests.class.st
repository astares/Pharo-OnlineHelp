Class {
	#name : #HelpServerTests,
	#superclass : #TestCase,
	#category : #'OnlineHelp-Tests'
}

{ #category : #testing }
HelpServerTests >> testPortAvailable [

	self assert: HelpServer port isInteger 
	

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
