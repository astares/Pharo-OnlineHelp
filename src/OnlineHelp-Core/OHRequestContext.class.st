"
Context of a web request
"
Class {
	#name : #OHRequestContext,
	#superclass : #Object,
	#instVars : [
		'request',
		'responseStream'
	],
	#category : #'OnlineHelp-Core-Web'
}

{ #category : #'instance creation' }
OHRequestContext class >> forRequest: aRequest [
	
	^(self new)
		request: aRequest;
		yourself
]

{ #category : #conversion }
OHRequestContext >> htmlResponse [
	"Reply with a dynamic HTML page"

	^ ZnResponse ok: (ZnEntity html: self responseStream contents)
]

{ #category : #'initialize-release' }
OHRequestContext >> initialize [ 
	super initialize.
	responseStream := String new writeStream 
]

{ #category : #accessing }
OHRequestContext >> request [
	^request
]

{ #category : #accessing }
OHRequestContext >> request: aRequest [
	request := aRequest 
]

{ #category : #accessing }
OHRequestContext >> responseStream [
	^responseStream 
]
