Class {
	#name : #PharoTutorial,
	#superclass : #Object,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPage1 [
	^'Pharo Page 1'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPage2 [
	^'Pharo Page 2'
]

{ #category : #'pharo tutorial' }
PharoTutorial class >> pharoTutorialOn: aBuilder [
	<onlineTutorial>
	
	(aBuilder tutorial: #'Pharo Tutorial')
		title: 'Pharo Tutorial';
		description: 'Overview of the Pharo environment and tools';
		addLesson:  ((aBuilder lesson: #'Lesson 1')
						title: 'The environment'; 
						description: 'The Pharo environment';
						addPage: #pharoIntroPage1 from: self;
						addPage: #pharoIntroPage2 from: self;	
						yourself)
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPage1 [
	^'Smalltalk Page 1'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPage2 [
	^'Smalltalk Page 2'
]

{ #category : #'smalltalk tutorial' }
PharoTutorial class >> smalltalkTutorialOn: aBuilder [
	<onlineTutorial>
	
	(aBuilder tutorial: #'Smalltalk Tutorial')
		title: 'Smalltalk Introduction';
		description: 'Overview of the Smalltalk language';
		addLesson:  ((aBuilder lesson: #'Lesson 1')
						title: 'The Basics'; 
						description: 'Smalltalk basics';
						addPage: #smalltalkIntroPage1 from: self;
						addPage: #smalltalkIntroPage2 from: self;	
						yourself)
]
