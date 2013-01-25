Class {
	#name : #OHTutorial,
	#superclass : #OHTutorialItem,
	#instVars : [
		'lessons'
	],
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #accessing }
OHTutorial >> addLesson: anOHTutorialLesson [ 
	self lessons add: anOHTutorialLesson 
]

{ #category : #accessing }
OHTutorial >> description [
	^description 
]

{ #category : #accessing }
OHTutorial >> lessons [
	lessons ifNil: [ lessons := OrderedCollection new ].
	^lessons
]
