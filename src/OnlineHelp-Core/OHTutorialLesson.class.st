Class {
	#name : #OHTutorialLesson,
	#superclass : #OHTutorialItem,
	#instVars : [
		'pageSelectors'
	],
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #accessing }
OHTutorialLesson >> addPage: aSymbol from: anObject [ 
	self pageSelectors add: anObject -> aSymbol
]

{ #category : #accessing }
OHTutorialLesson >> pageSelectors [
	pageSelectors ifNil: [pageSelectors := OrderedCollection new ].
	^pageSelectors
]
