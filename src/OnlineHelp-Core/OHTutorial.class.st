"
A tutorial
"
Class {
	#name : #OHTutorial,
	#superclass : #OHTutorialItem,
	#instVars : [
		'lessonMap'
	],
	#category : #'OnlineHelp-Core-Model'
}

{ #category : #accessing }
OHTutorial >> addLesson: aLesson [ 
	self lessonMap at: aLesson title asSymbol put: aLesson
]

{ #category : #'private accessing' }
OHTutorial >> lessonMap [
	lessonMap ifNil: [ lessonMap := OrderedIdentityDictionary new ].
	^lessonMap
]

{ #category : #accessing }
OHTutorial >> lessonNamed: aSymbol [
	^self lessonMap at: aSymbol ifAbsent: [nil]
]

{ #category : #accessing }
OHTutorial >> lessons [
	^lessonMap values
]
