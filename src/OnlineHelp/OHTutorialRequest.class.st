Class {
	#name : #OHTutorialRequest,
	#superclass : #OHHelpRequest,
	#category : #'OnlineHelp-Core-Web'
}

{ #category : #testing }
OHTutorialRequest >> hasLesson [
	^self lesson notNil 
]

{ #category : #testing }
OHTutorialRequest >> hasPage [
	^self page notNil 
]

{ #category : #testing }
OHTutorialRequest >> hasTutorial [
	^self tutorial notNil 
]

{ #category : #'accessing parts' }
OHTutorialRequest >> lesson [
	^httpRequest uri queryAt: 'lesson' ifAbsent: nil
]

{ #category : #'accessing parts' }
OHTutorialRequest >> page [
	^httpRequest uri queryAt: 'page' ifAbsent: 1
]

{ #category : #'accessing parts' }
OHTutorialRequest >> tutorial [
	^httpRequest uri queryAt: 'tutorial' ifAbsent: nil
]
