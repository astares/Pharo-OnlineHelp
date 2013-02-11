Class {
	#name : #OHAPIHelpRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #defaults }
OHAPIHelpRequestHandler >> prefix [
	"Return the prefix for tutorials"
	
	^'api'
]

{ #category : #defaults }
OHAPIHelpRequestHandler >> requestClass [
	^OHAPIHelpRequest 
]
