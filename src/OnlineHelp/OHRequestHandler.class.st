Class {
	#name : #OHRequestHandler,
	#superclass : #Object,
	#category : #'OnlineHelp-Core-Web'
}

{ #category : #testing }
OHRequestHandler class >> isAbstract [
	^self name == #OHRequestHandler 
]
