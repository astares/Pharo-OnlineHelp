Class {
	#name : #OHTutorialBuilder,
	#superclass : #Object,
	#instVars : [
		'tutorials'
	],
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #private }
OHTutorialBuilder class >> allTutorialDescriptions [
	 ^(PragmaCollector filter: [:pragma | #onlineTutorial = pragma keyword]) reset collected

]

{ #category : #accessing }
OHTutorialBuilder class >> availableTutorials [
	"Return all current available tutorials. This can later
	  be optimized by caching if necessary - currently 
	  always rebuild. We can later also add a ranking
	  mechanism so important tutorials show up higher"

	|builder|
	builder := (self new).
	builder build.
	^builder tutorials values
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
