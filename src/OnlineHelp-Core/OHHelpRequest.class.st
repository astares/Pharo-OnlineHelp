Class {
	#name : #OHHelpRequest,
	#superclass : #Object,
	#instVars : [
		'httpRequest',
		'prefix'
	],
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'instance creation' }
OHHelpRequest class >> fromHTTPRequest: anHTTPRequest [ 
	"Creates a new instance of the receiver initializes from the given HTTP request"
	
	^(self new)
		initFromHTTPRequest: anHTTPRequest;
		yourself
]

{ #category : #'private-initialization' }
OHHelpRequest >> initFromHTTPRequest: anHTTPRequest [
	httpRequest := anHTTPRequest.
	prefix := anHTTPRequest uri segments first.
	 
]

{ #category : #accessing }
OHHelpRequest >> prefix [
	 
	^ prefix
]