Class {
	#name : #PharoTutorial,
	#superclass : #Object,
	#category : #'OnlineHelp-Tutorials'
}

{ #category : #tutorial }
PharoTutorial class >> tutorial [
	<tutorial>

	^(HelpTutorial named: 'Introduction to Pharo')
		addLesson:  self lesson1;
		addLesson:  self lesson2;
		addLesson:  self lesson3;
		yourself 
	
]
