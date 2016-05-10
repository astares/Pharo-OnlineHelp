"
An OHTutorialBuilderTest is a test class for testing the behavior of OHTutorialBuilder
"
Class {
	#name : #OHTutorialBuilderTest,
	#superclass : #TestCase,
	#category : #'OnlineHelp-Tests-Core-Model'
}

{ #category : #accessing }
OHTutorialBuilderTest >> defaultTestClass [

	^OHTutorialBuilder 
]

{ #category : #tests }
OHTutorialBuilderTest >> testInstance [
	
	self assert: self defaultTestClass getInstance notNil 
	
]

{ #category : #tests }
OHTutorialBuilderTest >> testPickTutorialByName [
	
	| tutorial found |
	tutorial := self defaultTestClass availableTutorials first.
	found := self defaultTestClass tutorialWithName: tutorial title.
	self assert: found title = tutorial title
]

{ #category : #tests }
OHTutorialBuilderTest >> testTutorialsAvailable [
	
	self assert: self defaultTestClass availableTutorials notEmpty 
	
]
