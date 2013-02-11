Class {
	#name : #OHHelpRequestHandler,
	#superclass : #Object,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'request handling' }
OHHelpRequestHandler >> handleRequest: aRequest [
	
	| context |
	context := OHRequestContext forRequest: (self requestClass fromHTTPRequest: aRequest).
	self respondUsingContext: context.
	^context htmlResponse 
	
]

{ #category : #accessing }
OHHelpRequestHandler >> requestClass [
	^OHHelpRequest 
]
