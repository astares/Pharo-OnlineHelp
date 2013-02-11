Class {
	#name : #OHTutorialRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #defaults }
OHTutorialRequestHandler >> prefix [
	"Return the prefix for tutorials"
	
	^'tutorials'
]

{ #category : #defaults }
OHTutorialRequestHandler >> requestClass [
	^OHTutorialRequest 
]

{ #category : #rendering }
OHTutorialRequestHandler >> respondUsingContext: aContext [ 	

	aContext response nextPutAll: '<b>Hi</b>'
]
