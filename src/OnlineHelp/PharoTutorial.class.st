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
PharoTutorial class >> smalltalkIntroPage2 [
	^'Smalltalk Page 2'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page1 [
	^'
Objects and Messages
-----------------------------------

Everything in Smalltalk is on object, and all work is done by sending messages to objects.

To execute the following examples, open a new workspace in your Pharo environment 
and enter or copy the text there. <br/>
Then select the text using the left mouse button (as in 
a word processor). You can then execute the text with the <b>Print it</b> command 

<pre><code>
3 squared			"receiver is small integer 3"
''abc'' asUppercase	"receiver is string ''abc'' "
200 factorial			
</code></pre>

The Smalltalk syntax is easy to remember: an Object always comes first and a message follows.
So the object is the receiver of the message.

'
]

{ #category : #'smalltalk tutorial' }
PharoTutorial class >> smalltalkTutorialOn: aBuilder [
	<onlineTutorial>
	
	(aBuilder tutorial: #'Introduction to Smalltalk')
		description: 'An overview and introduction to the Smalltalk programming language';
		addLesson:  ((aBuilder lesson: #'Part 1: Objects and messages')					  
						description: 'Introduction to objects and messages';
						addPage: #smalltalkIntroPart1Page1 from: self;
						addPage: #smalltalkIntroPage2 from: self;	
						yourself)
]
