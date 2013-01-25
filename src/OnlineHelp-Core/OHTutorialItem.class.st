Class {
	#name : #OHTutorialItem,
	#superclass : #Object,
	#instVars : [
		'title',
		'description'
	],
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #accessing }
OHTutorialItem >> description: aString [ 
	 
	description := aString
]

{ #category : #accessing }
OHTutorialItem >> title [
	^title
]

{ #category : #accessing }
OHTutorialItem >> title: aString [ 
	 
	title := aString
]
