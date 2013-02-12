Class {
	#name : #PharoTutorial,
	#superclass : #Object,
	#category : #'OnlineHelp-Tutorials'
}

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPage1 [
	^'A First Level Header
====================

A Second Level Header
---------------------

Now is the time for all good men to come to
the aid of their country. This is just a
regular paragraph.

The quick brown fox jumped over the lazy
dog''s back.

### Header 3

> This is a blockquote.
> 
> This is the second paragraph in the blockquote.
>
> ## This is an H2 in a blockquote'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPage2 [
	^'
<code>Hello</code>'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPage3 [
	^'
<code>Hello</code>'
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
