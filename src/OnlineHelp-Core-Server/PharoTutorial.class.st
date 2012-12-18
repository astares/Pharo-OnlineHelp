Class {
	#name : #PharoTutorial,
	#superclass : #Object,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'as yet unclassified' }
PharoTutorial class >> tutorialOn: aBuilder [
	<onlineTutorial>
	
	(aBuilder tutorial: #'Pharo Tutorial')
		title: 'Pharo Tutorial';
		description: 'Overview of the Pharo environment and tools';
		addLesson:  ((aBuilder lesson: #'Lesson 1')
						title: 'The environment'; 
						description: 'The Pharo environment';
						addPage: #page1 from: self;
						addPage: #page2 from: self;	
						yourself)
]
