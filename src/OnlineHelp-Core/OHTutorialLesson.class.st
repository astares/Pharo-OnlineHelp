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
OHTutorialLesson >> contentForPage: aNumber [
	| pageSelector |
	pageSelector := self pageSelectors at: aNumber.
	^pageSelector key perform: pageSelector value
]

{ #category : #accessing }
OHTutorialLesson >> numberOfPages [
	^pageSelectors size
]

{ #category : #private }
OHTutorialLesson >> pageSelectors [
	pageSelectors ifNil: [pageSelectors := OrderedCollection new ].
	^pageSelectors
]
