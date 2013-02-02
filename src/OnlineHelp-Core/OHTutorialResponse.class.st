Class {
	#name : #OHTutorialResponse,
	#superclass : #Object,
	#instVars : [
		'request'
	],
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'instance creation' }
OHTutorialResponse class >> forRequest: aTutorialRequest [

	^(self new)
		request: aTutorialRequest;
		yourself
]

{ #category : #accessing }
OHTutorialResponse >> request [
	^request
]

{ #category : #accessing }
OHTutorialResponse >> request: aRequest [
	
	request := aRequest
]
