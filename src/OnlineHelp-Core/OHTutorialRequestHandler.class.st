Class {
	#name : #OHTutorialRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'request handling' }
OHTutorialRequestHandler >> handleRequest: aRequest [
	
	| tutorialRequest |
	tutorialRequest := OHTutorialRequest fromHTTPRequest: aRequest.
	tutorialRequest inspect.
	OHTutorialResponse forRequest: tutorialRequest.
	
	
	^ super handleRequest: aRequest
]

{ #category : #defaults }
OHTutorialRequestHandler >> prefix [
	"Return the prefix for tutorials"
	
	^'tutorials'
]
