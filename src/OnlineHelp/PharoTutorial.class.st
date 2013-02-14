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

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart1Page1 [
	^'
Overview
=======
To run Pharo you basically need four parts: 

 - a <font color="darkgreen"><b>virtual machine</b></font> to run pharo on your operating system platform 
 - an <font color="darkgreen"><b>image</b></font> file
 - a <font color="darkgreen"><b>changes</b></font> file
 - a <font color="darkgreen"><b>sources</b></font> file  

You can either download each part from <a href="http://files.pharo.org">http://files.pharo.org</a> or just download all of them together using the <b>"Pharo One click download"</b>  from <a href="http://www.pharo-project.org">http://www.pharo-project.org</a>
<br/><br/>
<img src="http://upload.wikimedia.org/wikipedia/commons/c/cf/Pharo.png" style="width: 50%"/><br/>

'

]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart1Page2 [	
	^'
The virtual machine
=============
Pharo is able to run on many different operating systems and platforms. This is achieved by using a platform dependent <b>virtual machine</b> (VM) that abstracts from the underlying platform and allows Pharo to run equally. 

So by default a program written in Smalltalk using Pharo is very portable and looks and behaves the same way on each platform. But Pharo also gives you the freedom to access platform specific features - so you can choose what is required for your application.

<img src="http://book.pharo-project.org/files/b5/yoxm6dildfmmg3i78kmtr711tronuw/environments.png"/>

There are virtual machines available for major operating systems like Windows, Mac, Linux, ... and also for mobiles platforms like Android. 
There are several versions of the virtual machine, but 2 most important kinds are:

 - <b>Classic</b> virtual machine
 - the new JIT based <b>Cog</b> virtual machine

Historically the Pharo VM is based on the Squeak Smalltalk virtual machine - a pluggable virtual machine which is partly written in a subset of Smalltalk (called <font color="brown"><b>Slang</b></font>) itself. There is a tool called <font color="brown"><b>VMMaker</b></font> that allows you to make changes and build your own VM if required.   

For instance there is a project called "<b>RoarVM</b>" - an adoption of the virtual machine to run Squeak and Pharo in parallel on many cores.




'

]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart1Page3 [	
	^'
The image file
==========

Pharo is a <b>dynamic object system</b> and this system is represented by a so called <font color="brown"><b>image</b></font>. The entire Smalltalk system (including all the objects in their current states)
can be persisted (saved) to a single file with an <b><i>.image</i></b> extension. <br/></br>
If you later open the image file again the Pharo system will continue to run at excactly the same point where you saved it before. You can even transfer an image file to a completely different OS platform and open it with the according virtual machine.

When you download a new fresh Pharo distribution the <b><i>default developer image</i></b> already contains tools and classes that form the Pharo system. You can modify this image to suit your needs. Typically you will add new code to create something new.

If you want to transfer your applications code to other images (like a <b><i>clean production image</i></b>) you can package it using using a tool called <font color="brown"><b>Monticello</b></font>.

For most developers coming from traditional environments this image concept is something new and hard to understand at the beginning. Once you work with it you will notice that it can make you very productive since it allows you to save the systems state at any point in time and continue later at will without a new setup. For instance you can save the system while debugging and continue to catch a bug in the debugger just the next day at exactly the same point.'

]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart2Page1 [
	^'
The Pharo Desktop
=============

When Pharo starts up you will see a single window called the Pharo desktop. 

<img src="http://book.pharo-project.org/files/ed/c5135wpi93rsei8s42z7ynlkghd3vr/pharostarted.png"/>

From here you can open all the necessary tools of the environment by using the <font color="red"><b>World menu</b></font>.
Just right click on the desktop to open the menu.
'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart2Page2 [
	^'
The World menu
===========

If you right click on the Pharo desktop you can open the <font color="red"><b>World menu</b></font>
Depending on the Pharo version and installed tools it may look a little bit different.
<img src="http://blog.openinworld.com/wp-content/uploads/2012/05/WorldMenu-comparison.png" style="width: 60%; padding: 20px;"/>

You can use it to access all the basic development tools like a <font color="brown"><b>Workspace</b></font>, the <font color="brown"><b>Transcript</b></font> and the <font color="brown"><b>System browser</b></font>.


'
]

{ #category : #'pharo tutorial' }
PharoTutorial class >> pharoTutorialOn: aBuilder [
	<onlineTutorial>
	
	(aBuilder tutorial: #'Pharo Tutorial')		 
		description: 'A short overview of the Pharo environment and tools';
		addLesson:  ((aBuilder lesson: #'The Pharo system')						 
						description: 'A short overview of the parts that make up the Pharo system. It should help you understand what is required to run Pharo on your operating system.';
						addPage: #pharoIntroPart1Page1 from: self;
						addPage: #pharoIntroPart1Page2 from: self;	
						addPage: #pharoIntroPart1Page3 from: self;	
						yourself);		
		addLesson:  ((aBuilder lesson: #'The Pharo environment')						 
						description: 'In this lesson you will learn how to use the Pharo environment.';
						addPage: #pharoIntroPart2Page1 from: self;
						addPage: #pharoIntroPart2Page2 from: self;	
						yourself);
		addLesson:  ((aBuilder lesson: #'Pharo Tools')						 
						description: 'In this lesson you will learn about the Pharo tools';
						addPage: #pharoIntroPage3 from: self;
						addPage: #pharoIntroPage4 from: self;	
						yourself)
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page1 [
	^'
Objects and Messages
-----------------------------------

Everything in Smalltalk is on object, and all work is done by sending messages to objects.

To execute the following examples, open a new workspace in your Pharo environment 
and enter or copy the text there. Then select the text using the left mouse button (as in 
a word processor). You can then execute the text with the <b>Print it</b> command 

<pre>
3 squared			"receiver is small integer 3"
''abc'' asUppercase	"receiver is string ''abc'' "
200 factorial			
</pre>

The Smalltalk syntax is easy to remember: an Object always comes first and a message follows.
So the object is the receiver of the message.

<img src="http://yuml.me/diagram/scruffy;/class/%5BObject%5D-%5Bnote:You%20can%20send%20messages%20to%20objects.%5D.png"/>

'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page2 [
	^'
Messages
---------------

There are exactly three kinds of messages: <font color="red">Unary</font>, <font color="red">binary</font>, and <font color="red">keyword</font>

### Unary ###
 	 
An unary message is just a word, there are no arguments:

<pre><code>
3 negated
''abcdefg'' vowels
</code></pre> 

 
 
                
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page3 [
	^'
Messages
---------------
 
  
 
                
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
						addPage: #smalltalkIntroPart1Page2 from: self;	
						addPage: #smalltalkIntroPart1Page3 from: self;	
						yourself)
]
