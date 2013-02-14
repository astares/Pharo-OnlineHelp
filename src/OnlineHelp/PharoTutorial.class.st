Class {
	#name : #PharoTutorial,
	#superclass : #Object,
	#category : #'OnlineHelp-Tutorials'
}

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
PharoTutorial class >> pharoIntroPart1Page4 [	
	^'
The sources and changes file
====================

For various reasons, the source code associated with the image is stored in two other files:

The code of the system as originally delivered is stored in the <b>source file</b> <font color="darkblue"><b>"PharoVxx.sources"</b></font>, and the sources for everything done since that time is in the <b>changes file</b> (which must similarly be named like the image but with an <b><i>.changes</b></i> extension) <font color="darkblue"><b>"ImageFileName.changes"</b></font>.

Storing the source code in a separate file has several advantages. To begin with, if you have been working for a couple of hours, and your dog rolls over the power cord, you will still have a sequential record of all your program edits, and these can be perused and replayed with numerous tools such as changes: post-snapshot log. This feature has also saved many who got too adventurous in changing the system he or she was using.

Also, if you wish to run the system with severely limited resources, it can be operated without any source code just by removing these files.

Finally, since the changes file does not consume memory space, Pharo keeps a continuous log of all your program changes, and these can be examined and reinstated at any time. 

So the sources/changes mechanism is <u>mostly for the system</u> to handle source code, track source code changes or recover after a crash. 

<u><b>Note</b></u>: For packaging your own source code (for instance for an application) you will use other mechanisms and source code/versioning tools like <font color="brown"><b>Monticello</b></font>.

'

]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart2Page1 [
	^'
The Pharo Desktop
=============

When Pharo starts up you will see a single window called the Pharo desktop. 

<img src="http://book.pharo-project.org/files/ed/c5135wpi93rsei8s42z7ynlkghd3vr/pharostarted.png" style="width: 50%"/>

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

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart2Page3 [
	^'
The update mechanism
================

Pharo includes a facility for automatically updating your system from a remote Pharo server.
If you are connected to the Internet you can easily update your system to the latest state.

In the <font color="red"><b>World menu</b></font> you will find an entry to update your system. Just right
click on the Pharo desktop in the Pharo window and select <font color="brown"><b>System -> Software update</b></font>.

<u><b>Note</b></u>: Any update changes your system - if you are unsure save your image first. 

Alternatively you can get the latest Pharo builds from

* the Pharo file server at http://files.pharo.org
* or the continuous integration (CI) server at http://ci.pharo.org
'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart2Page4 [
	^'
The settings browser
===============

All global preferences of Pharo can be viewed or changed from the Settings Browser.

In the <font color="red"><b>World menu</b></font> you will find an entry to update your system. Just right
click on the Pharo desktop in the Pharo window and select <font color="brown"><b>System -> Settings</b></font>.



Pharo includes a complete settings framework (see [Settings Declaration][1]) for that - you can use that easily for your own applications. 


[1]: http://book.pharo-project.org/book/Tidbits/CustomizingPharo/DeclaringSetting/  "Settings Declaration"

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
						addPage: #pharoIntroPart1Page4 from: self;	
						yourself);		
		addLesson:  ((aBuilder lesson: #'The Pharo environment')						 
						description: 'In this lesson you will learn how to use the Pharo environment.';
						addPage: #pharoIntroPart2Page1 from: self;
						addPage: #pharoIntroPart2Page2 from: self;	
						addPage: #pharoIntroPart2Page3 from: self;
						addPage: #pharoIntroPart2Page4 from: self;														
						yourself);
		addLesson:  ((aBuilder lesson: #'Pharo Tools')						 
						description: 'In this lesson you will learn about the Pharo tools';
						addPage: #pharoIntroPage3 from: self;
						addPage: #pharoIntroPage4 from: self;	
						yourself);
		addLesson:  ((aBuilder lesson: #'Learning Pharo')						 
						description: 'This section explains some useful resources to continue your tour with Pharo. We will tell you about the best places to learn about Pharo and the Smalltalk programming language';
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
