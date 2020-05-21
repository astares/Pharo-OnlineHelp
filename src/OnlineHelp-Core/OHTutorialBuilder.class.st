"
A builder to build tutorials
"
Class {
	#name : #OHTutorialBuilder,
	#superclass : #Object,
	#instVars : [
		'tutorials',
		'tutorialMap'
	],
	#category : #'OnlineHelp-Core-Model'
}

{ #category : #private }
OHTutorialBuilder class >> allTutorialDescriptions [
	 ^(PragmaCollector filter: [:pragma | #onlineTutorial = pragma key ]) reset collected

]

{ #category : #accessing }
OHTutorialBuilder class >> availableTutorials [
	"Return all current available tutorials. This can later
	  be optimized by caching if necessary - currently 
	  always rebuild. We can later also add a ranking
	  mechanism so important tutorials show up higher"

	^self getInstance tutorials  
]

{ #category : #private }
OHTutorialBuilder class >> getInstance [
	"Return a new builder This can later
	  be optimized by caching if necessary - currently 
	  always rebuild. We can later also add a ranking
	  mechanism so important tutorials show up higher"

	|builder|
	builder := (self new).
	builder build.
	^builder 
]

{ #category : #accessing }
OHTutorialBuilder class >> tutorialWithName: aName [
	"Returns a tutorial with the given name"

	^self getInstance tutorial: aName
	
]

{ #category : #building }
OHTutorialBuilder >> build [
	self class allTutorialDescriptions
		do:
			[ :each | each methodClass instanceSide perform: each method selector with: self ]
]

{ #category : #'initialize-release' }
OHTutorialBuilder >> initialize [
	super initialize.
	tutorialMap := Dictionary new.
]

{ #category : #accessing }
OHTutorialBuilder >> lesson: aSymbol [ 
	^OHTutorialLesson titled: aSymbol
]

{ #category : #accessing }
OHTutorialBuilder >> tutorial: aSymbol [ 
	^self tutorialMap at: aSymbol ifAbsentPut: (OHTutorial titled: aSymbol)
]

{ #category : #'private accessing' }
OHTutorialBuilder >> tutorialMap [
	^tutorialMap
]

{ #category : #accessing }
OHTutorialBuilder >> tutorials [
	^self tutorialMap values
]
