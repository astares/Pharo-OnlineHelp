Class {
	#name : #OHTutorialBuilder,
	#superclass : #Object,
	#instVars : [
		'tutorials'
	],
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'as yet unclassified' }
OHTutorialBuilder class >> allTutorialDescriptions [
	 ^(PragmaCollector filter: [:pragma | #onlineTutorial = pragma keyword]) reset collected

]

{ #category : #accessing }
OHTutorialBuilder >> build [
	self class allTutorialDescriptions do: [:each |
		each methodClass theNonMetaClass perform: each selector with: self
	]
]

{ #category : #'initialize-release' }
OHTutorialBuilder >> initialize [
	super initialize.
	tutorials := Dictionary new.
]

{ #category : #accessing }
OHTutorialBuilder >> lesson: aByteSymbol [ 
	^OHTutorialLesson new
]

{ #category : #building }
OHTutorialBuilder >> tutorial: aSymbol [ 
	^self tutorials at: aSymbol ifAbsentPut: OHTutorial new 
]

{ #category : #building }
OHTutorialBuilder >> tutorials [
	^tutorials
]
