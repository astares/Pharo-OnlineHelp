Class {
	#name : #OHTutorialFinder,
	#superclass : #Object,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'as yet unclassified' }
OHTutorialFinder class >> allTutorialDescriptions [
	 ^(PragmaCollector filter: [:pragma | #onlineTutorial:description: = pragma keyword]) reset collected

]
