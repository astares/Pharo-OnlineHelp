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
		description: 'A short overview of the Pharo environment and tools';
		addLesson:  ((aBuilder lesson: #'The Pharo environment')						 
						description: 'In this lesson you will learn how to use the Pharo environment.';
						addPage: #pharoIntroPage1 from: self;
						addPage: #pharoIntroPage2 from: self;	
						yourself);
		addLesson:  ((aBuilder lesson: #'Pharo Tools')						 
						description: 'In this lesson you will learn about the Pharo tools';
						addPage: #pharoIntroPage3 from: self;
						addPage: #pharoIntroPage4 from: self;	
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
	
	(aBuilder tutorial: #'Smalltalk Introduction')
		description: 'An overview and introduction to the Smalltalk programming language';
		addLesson:  ((aBuilder lesson: #'The Basics')					  
						description: 'Smalltalk basics';
						addPage: #smalltalkIntroPage1 from: self;
						addPage: #smalltalkIntroPage2 from: self;	
						yourself)
]
