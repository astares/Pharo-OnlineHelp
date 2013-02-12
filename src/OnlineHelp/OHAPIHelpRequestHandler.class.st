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

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderContentUsing: aContext [   

	
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderMenuUsing: aContext [ 
	aContext responseStream nextPutAll: self helpNavigationMenu 
]

{ #category : #defaults }
OHAPIHelpRequestHandler >> requestClass [
	^OHAPIHelpRequest 
]
