Class {
	#name : #HelpServerTests,
	#superclass : #TestCase,
	#category : #'OnlineHelp-Tests'
}

{ #category : #testing }
HelpServerTests >> testPortAvailable [

	self assert: HelpServer onlineHelpPort isInteger 
	

]

{ #category : #testing }
HelpServerTests >> testServerAccessibility [

	|server|	
	server := HelpServer server.
	self 
		assert: server notNil;
		assert: server port = HelpServer onlineHelpPort;
		assert: server isRunning = HelpServer isRunning 
		
	
	
]
