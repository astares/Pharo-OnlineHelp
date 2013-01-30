Class {
	#name : #OHTutorialItem,
	#superclass : #Object,
	#instVars : [
		'title',
		'description'
	],
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'instance creation' }
OHTutorialItem class >> titled: aUniqueTitle [
	^(self new)
		title: aUniqueTitle;
		yourself
]

{ #category : #accessing }
OHTutorialItem >> description: aString [ 
	 
	description := aString
]

{ #category : #accessing }
OHTutorialItem >> title [
	^title
]

{ #category : #accessing }
OHTutorialItem >> title: aSymbol [ 
	 
	title := aSymbol
]
