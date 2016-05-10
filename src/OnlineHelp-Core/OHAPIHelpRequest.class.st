"
A request for help on API
"
Class {
	#name : #OHAPIHelpRequest,
	#superclass : #OHHelpRequest,
	#category : #'OnlineHelp-Core-Web'
}

{ #category : #'accessing-parts' }
OHAPIHelpRequest >> action [
	^httpRequest uri queryAt: 'action' ifAbsent: self defaultAction
]

{ #category : #defaults }
OHAPIHelpRequest >> defaultAction [
	"Return the default action"
	
	^'comment'
]

{ #category : #defaults }
OHAPIHelpRequest >> defaultItem [
	"Return the default item"
	
	^'Object'
]

{ #category : #testing }
OHAPIHelpRequest >> hasAction [
	^self action notNil 
]

{ #category : #testing }
OHAPIHelpRequest >> hasItem [
	^self item notNil 
]

{ #category : #'accessing-parts' }
OHAPIHelpRequest >> item [
	^httpRequest uri queryAt: 'item' ifAbsent: self defaultItem
]

{ #category : #'accessing-parts' }
OHAPIHelpRequest >> itemAsRealClass [
	^Smalltalk at: self item asSymbol
]
