Class {
	#name : #OHRequestHandler,
	#superclass : #Object,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #testing }
OHRequestHandler class >> isAbstract [
	^self name == #OHRequestHandler 
]
